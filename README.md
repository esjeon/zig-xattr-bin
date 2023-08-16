zig-xattr
=========

This is a clone of [attr command][1] written in Zig. It basically reads and
writes xattr information of a file.

[1]: https://savannah.nongnu.org/projects/attr


Requirements
------------

This program is tested only on Linux.


Build
-----

This is a standard zig project that can be built with:

    zig build

It requires libc (for `perror`).


Usage
-----

The command line interface is similar to 

List all attributes of a file:

    xattr -l pathname

Get an attribute of a file:

    xattr -g attrname pathname

Set an attribute of a file ot a specific value:

    xattr -s attrname -V attrvalue pathname

Attribute value can be read from stdin, by omitting `-V` option:

    generate_some_output | xattr -s attrname pathname

Attributes can also be removed:

    xattr -r attrname pathname
