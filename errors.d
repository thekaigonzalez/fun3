module errors;

/* simple error system */
/++Authors: Kai D. Gonzalez ++/

import std.stdio : writefln;
import std.string : format;

struct WarningSettings
{
    bool fun3_newline_at_eof_warning = true;
}

enum WarningType
{
    FUN3_NEWLINE_AT_EOF_WARNING
}

/** 
 * A generic fun3 exception
 */
class F3Exception : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }
}

/** 
 * An unexpected token exception that has a similar format to:
 *   "unexpected token [token]"
 */
class F3UnexpectedTokenException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }
}

/**
 * unbalanced braces fun3 exception
*/
class F3UnbalancedBracesException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }
}

/** 
 * Throws an error based on `type`
 * Params:
 *   args = an array of strings containing arguments for the error. depending on
 *   the error these may not need to be used.
 *   type = the type of error to throw (default "F3Exception")
 *   exit_code = the exit code (default 1)
 * Returns: `exit_code`
 */
int error(string[] args, string type = "F3Exception", int exit_code = 1)
{
    switch (type)
    {
    case "F3Exception":
        throw new F3Exception("a generic fun3 exception has occurred.");
        break;
    case "F3UnexpectedTokenException":
        throw new F3UnexpectedTokenException("unexpected token '%s'".format(args[0]));
        break;
    case "F3UnbalancedBracesException":
        throw new F3UnbalancedBracesException("unbalanced braces");
        break;
    default:
        break;
    }

    return exit_code;
}

/**
    Throws a warning based on the WarningSettings object.
    NOTE: the WarningSettings object enables or disables certain warnings.
 */
void warning(WarningSettings settings, string msg, WarningType type)
{
    if (type == WarningType.FUN3_NEWLINE_AT_EOF_WARNING && settings.fun3_newline_at_eof_warning)
    {
        writefln("fun3: eof_warning: %s", msg);
    }
    else
    {
        writefln("warning: %s", msg);
    }
}
