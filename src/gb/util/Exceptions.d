/**
 * Exception stuff.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.Exceptions;

/**
 * Fabricates a new exception class.  The name has "Exception" appended to it
 * to determine the class' name.  The defaultMsg argument, if present, allows
 * for a default exception message if none is provided.
 * 
 * Example:
 * -----
 *  mixin SimpleException!("Foo", "oh noes!");
 *  
 *  static assert( is( SimpleException : Exception ) );
 *  
 *  void example()
 *  {
 *      throw new FooException("you broke it!");
 *  }
 * -----
 */

template SimpleException(char[] name, char[] defaultMsg = "")
{
    private const DEFAULT_MSG = defaultMsg;
    
    mixin(
        "class "~name~"Exception : Exception"
        ~ "{"
        ~ ( DEFAULT_MSG != ""
            ? "this() { super(DEFAULT_MSG); }"
              "this(char[] file, long line) { super(DEFAULT_MSG, file, line); }"
            : "" )
        ~ "this(char[] msg) { super(msg); }"
        ~ "this(char[] msg, char[] file, long line)"
                "{ super(msg, file, line); }"
        );
}
