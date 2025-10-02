/*
While the synchronous IO in the File module is easy to use and useful for many applications, there are
times when you don't want your program to stall while waiting for IO to complete (which often takes a
significant amount of time). If you are only using a few files or they need to be read/written sequentially,
you may consider making a new thread for your file IO which uses the synchronous API. But for more complex
applications that need to read many files at once, you may want an API for asynchronous IO that allows you
to submit read and write requests to the OS and have the OS notify you when the operations are complete.

There are many different ways for the OS to notify you about the completion of IO requests. It may be through a queue
or syscall that you poll, an interrupt or signal, or a syscall that blocks until some number of IO requests (or a
timeout) is complete. Based on the available APIs from Windows, macOS, and Linux we will be providing a procedure
that can be used to block until a request is completed and can be returned to you. During the creation of the queue,
you specify what information you would like to be returned. This procedure may be called from multiple threads if
you have a dedicated thread pool for file operations or you can call it from one thread for example to pass these
completion notifications to your own general thread pool. macOS and Linux will get better performance if you only
submit and wait from a single thread each (they could be the same or different threads) but this is unlikely to
matter outside of situations with very high IOPS where you likely want to make per-OS implementations anyway. You can
also use it for the situation where you just want to submit many requests at once and wait for them all to finish.

Similar to the File module, the ability to read or write an entire file is provided since those are the
most common operations. Additionally, reading and writing a specific portion of a file is provided which
may be useful for large files that contain a structure (such as a resources file that contains many
textures, sounds, models, etc). No support is provided for internal file cursors like most traditional
file APIs because those are rarely work the way you would like and can easily be created yourself.

On Linux, the API used is io_uring. We aren't using io_uring to it's full potential because it is almost impossible
to replicate that behaviour on other platforms so we had to choose behaviour that can be easily done everywhere. On
Windows, the API used is IO Completion ports. macOS is the outlier here. Both the Apple-intended way and the alternative
POSIX AIO method end up just creating worker threads. Using libDispatch creates those threads in userspace and AIO
does it in the kernel. We can't use libDispatch for many reasons but it's unlikely that we would want to anyway (though
using the kernel support for work queues may be possible and a good idea? That might require ensuring the user *isnt*
using libDispatch. Originally, I used POSIX AIO but the Darwin source indicates that this may not be better than
creating our own threads and the terrible API likely removes any of that benefit. The current version uses our own
thread pool.. The kernel creates 4 threads so we will do the same. Since these threads will not be doing very much
interesting work, I will use macOS-specific APIs to configure them to run only on efficiency cores when possible.

Opening files will block outside of Linux. This is because most APIs only allow doing the actual reads and writes
asynchronously even though opening files can block while waiting for metadata. Similarly, reading an entire file,
will block on getting the length of the file and writing an entire file will block on truncating the file. On
Linux, we dispatch those events to io_uring and wait to dispatch dependent events until the result is received.
Truncating hasn't been added to io_uring yet so that will block on all OSs. Because of these intermediate
operations, a call to wait_for_completion may receive multiple completion notifications before returning.

Some of these functions may allocate though that has been avoided where possible. All platforms
use the temporary allocator for file names (converting to C strings on macOS and Linux and
converting to wide strings on Windows). These strings can be freed when the open call returns.
*/

/*
 Future improvements:
  * Allow opening a file in read-only mode in case you don't have write permissions
  * Make a better API for errors that can handle errors from async open and from close. Maybe require receiving
    a completion for them? There is currently no way to know if an error happened with writing that was not
    caught until the file was closed. Perhaps we need to add a sync method so that you can check for those
    errors that would otherwise be unknown. This will become apparent as the module is used in real programs.
  * When returning Incomplete as an error, there is no way to know how much has been done.
  * Automatically switch to using thread_pool on Linux if io_uring is not supported?
  * Have a way to specify the allocator to use for read_entire_file. It currently uses the context
    allocator on Windows and Linux and the allocator that was in the context when creating the queue
    for macOS. For now, if you want consistant results across platforms, ensure those are the same.
    Maybe the queue should store that allocator. It also might be a good idea to store the allocator
    used for allocating OVERLAPPED structures on Windows, FileOperation and File.internal on Linux, and
    file.unfinished_operations on macOS. Possibly internally using some kind of efficient fixed-size allocator.
  * For large files, make multiple requests in parallel.
  * Fix the issue on Linux with saving space for requests with
    multiple entries. Maybe the following improvements would help.
  * On Linux, create a separeate queue for open and have that queue be checked by submissions to invalid files so
    that you won't miss open completions if you add all of your other operations before calling wait_for_completion.
  * On macOS, use a similar system to Linux that allows open to be done on a worker thread (probably not worth it).
  * It may be possible to make Linux be wait-free or at least closer to wait-free
    with sigificantly more thinking (or someone more experienced with syncronization).
*/

/*
API found in thread_pool.jai, io_completion_ports.jai, and io_uring.jai

// Stores platform-specific information about the queue
Queue :: struct(User_Data: Type)
// Stores platform-specific file handle, descriptor, etc
File :: struct(User_Data: Type)

// Errors here can only be Success or Catastrophic
initialize_queue :: ($User_Data: Type) -> *Queue(User_Data), Error

destroy_queue :: (queue: *Queue)

// file_path only needs to be valid until these calls return
open_file  :: (queue: *Queue, file_path: string, keep_existing_content := true) -> File, Error
close_file :: (queue: *Queue, file: File)

// The array of read data will be given in the return from wait_for_completion
read_entire_file  :: (queue: *Queue($T), file_path: string, user_data: T) -> Error
write_entire_file :: (queue: *Queue($T), file_path: string, data: [] u8, user_data: T) -> Error

read_file  :: (queue: *Queue($T), file: File, position: s64, data: [] u8, user_data: T) -> Error
write_file :: (queue: *Queue($T), file: File, position: s64, data: [] u8, user_data: T) -> Error

// Set check_only to return if no entries are available
wait_for_completion :: (queue: *Queue($T), check_only := false) -> T, data: [] u8, Error
*/

// On Windows, MSDN states that because errors can bubble up from drivers etc, the docs can't list every possible
// error. Unhelpfully, it also lets us know that the docs for most functions won't even include a partial list. So
// some errors we return as catastrophic may be recoverable or even expected in some circumstances. On the other
// hand, some errors we report as incomplete (especially if the completed amount is zero) may be unrecoverable or
// indicate other larger issues with the system; exactly the kinds of errors that we would like to return catastrophic
// for. Thus it would be appreciated if any logging would include the platform_code so that in those cases, we can
// update the error handling. Linux and macOS list all possible errors on the man pages but some are historical
// and supposedly not returned by modern versions of either OS. But just in case (and in case they break the
// standard and return something weird anyway) it would be great to log the error codes on those platforms as well.
Error :: struct {
    code: enum {
        Success :: 0;
        DidNotWait;       // Check_only was specified on wait_for_completion and no completion was found.
        FullQueue;        // The submission queue was full so retry after waiting or calling wait_for_completion.
        FileAccessFailed; // Either the file doesn't exist, you don't have access to it, or similar.
        Incomplete;       // Not all data was read or written (file changed under you, IO error, etc).
        Catastrophic;     // Errors that should only happen in exceptional circumstances (you might assert on this).
    };
    // Errno on Unix, GetLastError on Windows. s64 can fit both types and probably any future types.
    // Use get_error_string in the System module to get the name of the error. This may be set to
    // 0 even in the case of an error if the error is not associated with a platform error code.
    platform_code: s64;
}

#if OS == .WINDOWS {
    #load "io_completion_ports.jai";
} else #if OS == .LINUX {
    // #load "thread_pool.jai"; // Uncomment to test or if you are using an old kernel
    #load "io_uring.jai";
} else #if OS == .MACOS {
    #load "thread_pool.jai";
} else {
    #assert false "File_Async only supports Windows, Linux, and macOS. Other POSIX OSs may work with thread_pool.";
}

#scope_module
error :: (code: type_of(Error.code), platform_code: $T = 0) -> Error {
    ret: Error = ---;
    ret.code = code;
    ret.platform_code = xx platform_code;
    return ret;
}
