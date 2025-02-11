SAMPLE_Jai :: #string JAI
// Comment
/* Multi-line comment */
#import "Module";

main :: () {
    print("%\n", type_of(Address));
}

HEREDOC :: #string LANG_C
#include <stdio.h>

int main(int argc, char **argv) {
    printf("Hello, world!\n");
    return 0;
}
LANG_C

value :: #run enum_highest_value(Enum);

#scope_module

Address :: struct {
    street_number: int;
    street_name:   string;
}

#scope_file

file_scoped_function :: () -> int {
    return 4;  // chosen by fair dice roll
}

Phone_Number :: [9] u8;
JAI


SAMPLE_Rust :: #string RUST
// Comment
/* Multi-line comment */

use std::mem;

macro_rules! print_char {
    () => {
        println!("{}", 'A')
    };
}

pub fn main() {
    println!("Hello, world!");

    let some_array: [i32; 4] = [4, 3, 2, 1];
    for mut _element in some_array {
        _element += some_array.len() as i32;
        _element += mem::size_of_val(&some_array) as i32;
    }

    let _some_struct = Structure {
        is_true: true,
        text: String::from(r"raw string"),
    };

    print_char!()
}

#[repr(packed(8))]
#[allow(dead_code)]
pub struct Structure {
    is_true: bool,
    text: String,
}
RUST

SAMPLE_Python :: #string PYTHON
# Comment
from numpy import random

class Class:
    """
    Docstring
    """
    def __init__(self, istrue, text):
        self.istrue = istrue
        self.text = text

    def __str__(self):
        return f"{self.text}"

def main():
    print("Hello, world!")

    some_list = [4, 3, 2, 1]
    try:
        for element in some_list:
            element += int(random.rand())
            element += len(some_list)
    except:
        print('A')

    some_object = Class(True, r"raw string")
    print(some_object)

if __name__ == "__main__":
    main()

PYTHON

SAMPLE_C :: #string LANG_C
// Comment
/* Multi-line comment */

#include <stdio.h>
#include <stdbool.h>
#define length(x) sizeof(x) / sizeof(x[0])

typedef struct
{
    bool is_true;
    char text[20];
} Structure;

int main()
{
    printf("Hello World!");
    unsigned int some_array[4] = { 4, 3, 2, 1 };

    for (int i = 0; i < length(some_array); i++)
    {
        some_array[i] += i + sizeof(some_array);
    }

    Structure some_struct = { true, "string" };
    char some_char = 'c';
}

LANG_C

SAMPLE_Cpp :: #string LANG_CPP
// Comment
/* Multi-line comment */

#include <iostream>
#include <string>
#define length(x) sizeof(x) / sizeof(x[0])

typedef struct
{
    [[deprecated]] bool is_true;
    std::string text;
} Structure;

int main()
{
    std::cout << "Hello world!" << std::endl;
    unsigned int some_array[4] = { 4, 3, 2, 1 };

    for (int i = 0; i < length(some_array); i++)
    {
        some_array[i] += i + sizeof(some_array);
    }

    Structure some_struct;
    some_struct.is_true = true;
    some_struct.text = R"(raw string)";
    char some_char = 'c';
}

LANG_CPP

SAMPLE_CSharp :: #string CSHARP
// Comment
/* Multiline Comment */
using System;

[Serializable]
class Program
{
    public readonly struct Structure
    {
        public Structure(bool isTrue, string text)
        {
            IsTrue = isTrue;
            Text = text;
        }
        #nullable enable
        public bool IsTrue { get; init; }
        public string Text { get; init; }

        public override string ToString() => $"{Text}";
    }

    static void Main()
    {
        Console.WriteLine("Hello world!");
        int[] someArray = new int[4];
        for (int i = 0; i < 4; i++)
        {
            someArray[i] = someArray.Length + sizeof(int);
        }

        var someStruct = new Structure(true, """raw string""");
        char someChar = 'a';
    }
}

CSHARP

SAMPLE_Java :: #string JAVA
package org.example.java;

import java.util.Date;
import java.util.ArrayList;
import org.apache.commons.*;
import static SomeClass.STATIC_FIELD;

/**
 * Documentation for <code>SomeClass</code> --- @see Math#sin(double)
 * @param T a type that extends Runnable
 */
@Annotation(param1 = "value1", param2 = "value2")
@SuppressWarnings({"ALL"})
public class SomeClass<T extends Runnable> implements SomeInterface, SomeOtherInterface {
    @JsonElement
    private T field                     = null;
    private double doubleField          = 12345.67890;         // inline comment
    @Value("${system.someString}")
    private String someString           = "\nSome String \n";

    /*
        Multiline comment
    */
    final int packagePrivateField       = 2;
    protected final int protectedField  = 3;
    public final int instanceFinalField = 2;
    public static int STATIC_FIELD      = 3;

    /**
     * Method documentation
     * @param param
     */
    public SomeClass(int[] param) {
        int intValue = this.STATIC_FIELD + param[0] + 5;
        long data    = (long) doubleField;
        int[] f      = new int[]{1, 1, 2, 3, 5, 8, 13, 21};

        ArrayList history      = new ArrayList<List<? extends SomeOtherClass>>(); // nested generic types
        ArrayList<String> list = new ArrayList<>();                               // implicit generic type
        list                   = new ArrayList<String>().toArray(new int[23]);    // explicit generic type

        for (String stringValue: list) {
            for (int i = 0; i < 4; i++) {
                System.out.println(String.format("%d [string: %s (%d)]", i, stringValue, intValue));
                intValue++;
            }
        }
    }

    @Override
    public <E extends T> E addAll(Collection<T> collection) {
        // ...
    }

    @Deprecated
    public static <T> void merge(List<T> dest, List<? extends T> src) {
        // ...
    }
}

JAVA

SAMPLE_Odin :: #string ODIN
// Comment
/* Multi-line comment */
package main

import "core:fmt"
DIRECTIVE :: #config(DIRECTIVE, 20)
Char_Set :: bit_set['A'..='Z'; u32]

@(cold)
main :: proc() {
    defer fmt.println("Hellope!")
    some_array : [4]int = { 4, 3, 2, 1 }

    for i in 0..<4 {
        some_array[i] += i + len(some_array)
    }

    some_struct : Structure = { true, `raw string` }
}

Structure :: struct {
    is_true:    bool,
    text:        string,
}

ODIN


SAMPLE_Css :: #string LANG_CSS
/* Comment */
/*
   Multiline Comment
*/
@import url("https://example.com/style.css");

:root {
    --main-color: #3498db;
    --secondary-color: rgba(255, 255, 255, 0.8);
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: "Arial", sans-serif;
    color: var(--main-color);
    background-color: #f0f0f0;
}

h1, h2, h3 {
    color: var(--secondary-color);
    margin: 10px;
}

a {
    text-decoration: none;
    color: #2980b9;
    transition: color 0.3s ease-in-out;
}

a:hover {
    color: #e74c3c;
}

.container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 15px;
    padding: 20px;
}

.button {
    background-color: #2ecc71;
    border: none;
    border-radius: 5px;
    color: white;
    padding: 10px 20px;
    cursor: pointer;
}

.button:disabled {
    background-color: #95a5a6;
    cursor: not-allowed;
}
LANG_CSS


SAMPLE_D :: #string LANG_D
#!rdmd

// Comment
/* Multi-line comment */
/+ /+ Nested +/ multi-line comment +/

import std.stdio : writeln;

struct Structure
{
    bool isTrue;
    char[20] text;
}

void main()
{
    writeln("Hello World!");
    uint[4] someArray = [4, 3, 2, 1];

    foreach (i; 0..someArray.length)
    {
        someArray[i] += i + someArray.sizeof;
    }

    Structure some_struct = { true, "string" };
    char some_char = 'c';
}

LANG_D


SAMPLE_Glsl :: #string GLSL
// Comment
/* Multiline Comment */
#version 450

precision mediump float;

uniform vec3 lightPosition;
uniform mat4 modelViewMatrix;
uniform sampler2D textureSampler;

in vec3 fragNormal;
in vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    vec3 normal = normalize(fragNormal);
    vec4 texColor = texture(textureSampler, fragTexCoord);
    float lightIntensity = max(dot(normal, normalize(lightPosition)), 0.0);

    vec3 ambient = vec3(0.1, 0.1, 0.1);
    vec3 diffuse = lightIntensity * vec3(1.0, 1.0, 1.0);

    fragColor = vec4(ambient + diffuse, 1.0) * texColor;
}
GLSL


SAMPLE_Hlsl :: #string HLSL
// Comment
/* Multiline Comment */
cbuffer MatrixBuffer : register(b0)
{
    matrix worldMatrix;
    matrix viewMatrix;
    matrix projectionMatrix;
}

Texture2D shaderTexture : register(t0);
SamplerState sampleType : register(s0);

struct VertexInputType
{
    float4 position : POSITION;
    float2 tex : TEXCOORD0;
    float3 normal : NORMAL;
};

struct PixelInputType
{
    float4 position : SV_POSITION;
    float2 tex : TEXCOORD0;
    float3 normal : NORMAL;
};

PixelInputType VertexShader(VertexInputType input)
{
    PixelInputType output;

    // Calculate the position of the vertex.
    output.position = mul(input.position, worldMatrix);
    output.position = mul(output.position, viewMatrix);
    output.position = mul(output.position, projectionMatrix);

    // Pass through the texture coordinates.
    output.tex = input.tex;

    // Pass through the normal vector.
    output.normal = mul(input.normal, (float3x3)worldMatrix);

    return output;
}

float4 PixelShader(PixelInputType input) : SV_TARGET
{
    float3 lightDir = normalize(float3(0.0f, 1.0f, -1.0f));
    float lightIntensity = saturate(dot(input.normal, lightDir));

    float4 textureColor = shaderTexture.Sample(sampleType, input.tex);

    return float4(textureColor.rgb * lightIntensity, textureColor.a);
}

technique10 SimpleTechnique
{
    pass Pass1
    {
        SetVertexShader(CompileShader(vs_4_0, VertexShader()));
        SetPixelShader(CompileShader(ps_4_0, PixelShader()));
    }
}

HLSL


SAMPLE_Golang :: #string GOLANG
// Comment
/* Multiline Comment */
package main

import (
    "fmt"
    "math"
    "strings"
)

const Pi = 3.14159

type Person struct {
    FirstName string
    LastName  string
    Age       int
}

func (p *Person) FullName() string {
    return p.FirstName + " " + p.LastName
}

func main() {
    var number int = 42
    var isTrue bool = true
    message := "Hello, Go!"

    fmt.Println(message)

    if isTrue {
        fmt.Printf("The number is %d\n", number)
    }

    switch dayOfWeek := "Monday"; dayOfWeek {
    case "Monday":
        fmt.Println("Start of the work week.")
    case "Friday":
        fmt.Println("Almost the weekend!")
    default:
        fmt.Println("Midweek days.")
    }

    for i := 0; i < 5; i++ {
        fmt.Println("Iteration:", i)
    }

    person := Person{FirstName: "John", LastName: "Doe", Age: 30}
    fmt.Println("Full Name:", person.FullName())

    area := math.Pi * math.Pow(10, 2)
    fmt.Printf("Area of the circle: %.2f\n", area)

    words := []string{"Go", "is", "awesome!"}
    sentence := strings.Join(words, " ")
    fmt.Println(sentence)
}

GOLANG


SAMPLE_Js :: #string LANG_JS
// Comment
/* Multiline Comment */
"use strict";

const PI = 3.14159;

class Person {
    constructor(firstName, lastName, age) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.age = age;
    }

    getFullName() {
        return `${this.firstName} ${this.lastName}`;
    }
}

function greet(name) {
    return `Hello, ${name}!`;
}

function calculateArea(radius) {
    if (radius <= 0) {
        throw new Error("Radius must be greater than zero");
    }
    return PI * Math.pow(radius, 2);
}

const numbers = [1, 2, 3, 4, 5];

for (let i = 0; i < numbers.length; i++) {
    console.log(`Number: ${numbers[i]}`);
}

try {
    let area = calculateArea(10);
    console.log(`Area: ${area}`);
} catch (error) {
    console.error(error.message);
}

let person = new Person("John", "Doe", 25);
console.log(person.getFullName());

let isTrue = true;
let message = isTrue ? greet(person.firstName) : "Goodbye!";
console.log(message);

async function fetchData(url) {
    try {
        let response = await fetch(url);
        let data = await response.json();
        console.log(data);
    } catch (error) {
        console.error("Error fetching data:", error);
    }
}

fetchData("https://api.example.com/data");

LANG_JS


SAMPLE_Json :: #string JSON
{
    "name": "John Doe",
    "age": 30,
    "isStudent": false,
    "address": {
        "street": "123 Main St",
        "city": "Anytown",
        "state": "CA",
        "postalCode": "12345"
    },
    "phoneNumbers": [
        {
            "type": "home",
            "number": "555-1234"
        },
        {
            "type": "work",
            "number": "555-5678"
        }
    ],
    "email": "johndoe@example.com",
    "website": null,
    "languages": [
        "English",
        "Spanish",
        "French"
    ],
    "isVerified": true,
    "metadata": {
        "createdAt": "2024-08-24T12:34:56Z",
        "lastLogin": "2024-08-23T09:21:15Z"
    }
}

JSON


SAMPLE_Lua :: #string LUA
-- Comment
--[[
    Multiline Comment
--]]

local PI = 3.14159

local function calculateArea(radius)
    if radius <= 0 then
        error("Radius must be greater than zero")
    end
    return PI * radius * radius
end

local numbers = {1, 2, 3, 4, 5}

for i = 1, #numbers do
    print("Number:", numbers[i])
end

local person = {
    firstName = "John",
    lastName = "Doe",
    age = 30,
    getFullName = function(self)
        return self.firstName .. " " .. self.lastName
    end
}

print("Full Name:", person:getFullName())

local isTrue = true
local message = isTrue and "Hello, Lua!" or "Goodbye!"
print(message)

local status, result = pcall(calculateArea, 10)
if status then
    print("Area:", result)
else
    print("Error:", result)
end

local function fetchData(url)
    -- Simulate fetching data from a URL
    print("Fetching data from:", url)
    return {
        success = true,
        data = {
            id = 1,
            name = "Sample Data"
        }
    }
end

local data = fetchData("https://api.example.com/data")
if data.success then
    print("Data fetched:", data.data.name)
end


LUA


SAMPLE_RenPy :: #string RENPY
# Comment
# Ren'Py script for a simple visual novel

label start:
    scene bg room
    with dissolve

    # Define character
    define e = Character("Eileen", color="#c8ffc8")

    # Dialogue
    e "Hello, world!"

    menu:
        "Ask about the weather":
            e "It's a nice day today, isn't it?"
            jump weather

        "Say goodbye":
            e "Goodbye then!"
            return

label weather:
    e "I heard it might rain later."
    e "Better take an umbrella, just in case."

    $ has_umbrella = True

    if has_umbrella:
        e "Good thing I brought an umbrella with me!"
    else:
        e "I should've brought an umbrella."

    return

# Python block
python:
    def custom_function():
        return "This is a custom function in Ren'Py."

    result = custom_function()
    renpy.say(None, result)

# Image and transition
image bg room = "images/room.png"
image eileen happy = "images/eileen_happy.png"

# Show image
show eileen happy
with dissolve

e "I'm so happy today!"

return

RENPY


SAMPLE_Xml :: #string XML
<!-- Comment -->
<!--
    Multiline Comment
-->
<note>
    <to>Tove</to>
    <from>Jani</from>
    <heading>Reminder</heading>
    <body>Don't forget me this weekend!</body>
    <date>2024-08-24</date>
    <priority level="high">1</priority>
</note>

<bookshelf>
    <book id="1" genre="fantasy">
        <title>The Hobbit</title>
        <author>J.R.R. Tolkien</author>
        <year>1937</year>
        <price currency="USD">22.99</price>
        <availability>In Stock</availability>
    </book>
    <book id="2" genre="science fiction">
        <title>Dune</title>
        <author>Frank Herbert</author>
        <year>1965</year>
        <price currency="USD">18.99</price>
        <availability>Out of Stock</availability>
    </book>
</bookshelf>

<settings>
    <option name="volume" value="80"/>
    <option name="resolution" value="1920x1080"/>
    <option name="fullscreen" value="true"/>
    <colors>
        <background>#ffffff</background>
        <foreground>#000000</foreground>
    </colors>
</settings>

XML


SAMPLE_Html :: #string LANG_HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Comment -->
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sample HTML</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f0f0f0;
        }
    </style>
</head>
<body>
    <header>
        <h1>Welcome to My Website</h1>
        <nav>
            <ul>
                <li><a href="#home">Home</a></li>
                <li><a href="#about">About</a></li>
                <li><a href="#contact">Contact</a></li>
            </ul>
        </nav>
    </header>

    <main>
        <section id="home">
            <h2>Home Section</h2>
            <p>This is the home section of the website.</p>
            <img src="image.jpg" alt="Sample Image">
        </section>

        <section id="about">
            <h2>About Section</h2>
            <p>This section contains information about the website.</p>
            <a href="https://example.com" target="_blank">Visit Example</a>
        </section>

        <section id="contact">
            <h2>Contact Section</h2>
            <form action="/submit" method="post">
                <label for="name">Name:</label>
                <input type="text" id="name" name="name" required>
                <label for="email">Email:</label>
                <input type="email" id="email" name="email" required>
                <label for="message">Message:</label>
                <textarea id="message" name="message"></textarea>
                <button type="submit">Submit</button>
            </form>
        </section>
    </main>

    <footer>
        <p>&copy; 2024 My Website</p>
    </footer>
</body>
</html>

LANG_HTML


SAMPLE_Todo :: #string LANG_TODO
# Header

+ Item 1 done
+ Item 2 done
    + Subitem 1 done
    + Subitem 2 done
    - Subitem 3 to do
* Item 3 - work in progress
- Item 4 to do

LANG_TODO


SAMPLE_Yang :: #string LANG_YANG
module example-module {
    namespace "urn:example:params:xml:ns:yang:example-module";
    prefix ex;

    organization "Example Organization";
    contact "contact@example.com";

    description
        "This module defines an example YANG model.";

    revision "2024-08-24" {
        description "Initial revision.";
    }

    container system {
        description "Top-level container for system configuration.";

        leaf hostname {
            type string;
            description "The system's hostname.";
        }

        leaf ip-address {
            type inet:ipv4-address;
            description "The system's IP address.";
        }

        leaf-list dns-servers {
            type inet:ipv4-address;
            description "List of DNS servers.";
        }

        list interface {
            key "name";
            description "List of network interfaces.";

            leaf name {
                type string;
                description "The name of the interface.";
            }

            leaf enabled {
                type boolean;
                default "true";
                description "Specifies whether the interface is enabled.";
            }

            leaf mtu {
                type uint16 {
                    range "576..9000";
                }
                default "1500";
                description "The Maximum Transmission Unit (MTU) size.";
            }
        }
    }
}

LANG_YANG


SAMPLE_Zig :: #string LANG_ZIG
// Comment

const std = @import("std");

const Point = struct {
    x: f32,
    y: f32,

    pub fn distance(self: Point, other: Point) f32 {
        return std.math.sqrt((self.x - other.x) ** 2 + (self.y - other.y) ** 2);
    }
};

fn greet(name: []const u8) void {
    std.debug.print("Hello, {}!\n", .{name});
}

pub fn main() void {
    var stdout = std.io.getStdOut().writer();
    const point1 = Point{ .x = 1.0, .y = 2.0 };
    const point2 = Point{ .x = 4.0, .y = 6.0 };

    const distance = point1.distance(point2);
    _ = stdout.print("Distance: {}\n", .{distance});

    const names = [_][]const u8{"Alice", "Bob", "Charlie"};
    for (names) |name| {
        greet(name);
    }

    const multi_line_string = \\ Hello
                              \\ World
        ;

    var counter: u32 = 0;
    while (counter < 10) : (counter += 1) {
        if (counter % 2 == 0) {
            std.debug.print("{} is even\n", .{counter});
        } else {
            std.debug.print("{} is odd\n", .{counter});
        }
    }

    // Error handling
    const result = try someFunction();
    _ = stdout.print("Result: {}\n", .{result});
}

fn someFunction() !i32 {
    return 42;
}

LANG_ZIG


SAMPLE_Uxntal :: #string LANG_UXNTAL
( Comment )
( Multiline
  Comment )

|00 @main
    ; This is the main entry point

    LIT $0a       ( Push the literal value 0a onto the stack )
    LIT2 $1234    ( Push the 2-byte literal 1234 onto the stack )
    ADD2          ( Add the top two 2-byte values on the stack )

    #10 .System/rhalt DEO ( Halt the system )

|0100
@subroutine
    LIT #1
    LIT2 #0020
    JCN @subroutine_return ( Jump if zero to subroutine_return )
    INC2
@subroutine_return
    RTN  ( Return from subroutine )

|1000 ( Zero Page )
    @flag .byte $00
    @counter .word $0000

|2000 ( Stack )
    @stack_begin
    @stack_end

LANG_UXNTAL


SAMPLE_Markdown :: #string MARKDOWN
# Sample Markdown Document

## Heading Level 2

This is a paragraph with **bold text**, *italic text*, and `inline code`.

> This is a blockquote.
>
> It can span multiple lines.

1. First ordered list item
2. Second ordered list item
   - Nested unordered list
   - Another item

- Unordered list item
- Another item

### Code Block

```python
def hello_world():
    print("Hello, world!")
```

### Links and Images

[Visit Example](https://example.com)

![Alt text for the image](https://example.com/image.png)

### Table

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Row 1    | Data 1   | Data 2   |
| Row 2    | Data 3   | Data 4   |

### Task List

- [x] Task 1
- [ ] Task 2
- [ ] Task 3

### Horizontal Rule

---

This is a footnote reference[^1].

[^1]: This is the footnote text.

MARKDOWN


SAMPLE_Batch :: #string BATCH
@echo off

rem This is a comment.

set property=first name
set /p username="Please enter your %property%: "
echo Hello, %username%! Nice to meet you. & echo.

set counter=5
echo Counting down from %counter%...

:countdown
if %counter% LEQ 0 (
    echo.
    goto fruits
)
echo %counter%
set /a counter=%counter%-1
goto countdown

:fruits
echo Displaying some fruits for you, %username%:

for %%i in (apple, mango, elderberry) do (
    echo %%i
)

:end
BATCH

SAMPLE_Swift :: #string SWIFT
import Foundation

class Car {
    var make: String
    var model: String
    var year: Int
    var isEngineOn: Bool = false

    init(make: String, model: String, year: Int) {
        self.make = make
        self.model = model
        self.year = year
    }

    func startEngine() {
        if !isEngineOn {
            isEngineOn = true
            print("The engine is now on.")
        } else {
            print("The engine is already running.")
        }
    }

    func stopEngine() {
        if isEngineOn {
            isEngineOn = false
            print("The engine is now off.")
        } else {
            print("The engine is already off.")
        }
    }

    func displayDetails() {
        print("\(year) \(make) \(model)")
    }
}

let myCar = Car(make: "Toyota", model: "Corolla", year: 2020)
myCar.displayDetails()
myCar.startEngine()
myCar.stopEngine()

SWIFT

SAMPLE_Shell :: #string LANG_SHELL
#!/bin/bash

shopt -s nocaseglob
set -xe

# This is a comment.

function usage () {
    echo "Usage: ${0##*/} <name>" >&2
}

NAME=${1}
if [[ -z ${NAME} ]]; then
    echo "Sir, we cannot procceed without your name!" >&2
    usage
    exit 1
elif [[ "${NAME}" = "poop" ]]; then
    echo "...There's no way your name is \"poop.\" Try again." >&2
    exit 1
fi

echo "Hello, ${NAME}! Nice to meet you."

COUNTER=$(( ${RANDOM} % 200 ))  # Random number in [0, 200)
COUNTER=$(( ${COUNTER} + 1 ))   # Change number to [1, 200]

echo -ne "----- Counting down from $COUNTER... -----\n"

for (( i = $COUNTER ; i >= 0 ; i-- )); do
    echo "${i}..."
done

echo -e "\n----- Displaying some fruits... -----"

FRUITS=("apple" "mango" "elderberry")
for fruit in "${FRUITS[@]}"; do
    echo "We have a(n) ${fruit:-missing fruit??}!"
done

printf "\n"

cat << DONE
----- Mutiline strings... ------
This is a multiline string!
This is what inspired Jai's #string functionality.
Isn't it neat?
DONE

LANG_SHELL


SAMPLE_Ini :: #string LANG_INI
; INI Parse sample.

[Section 1]
SomeInt = 123 ; that is indeed some int
SomeString = "This is a string"

[Section 2]
SomeOtherInt = 1234
CombinedValue = "This is " a different 'string'   ; fancy

[Section 3]
MultiLineString = "This string
extends to multiple
lines"
StillOk = true

LANG_INI
