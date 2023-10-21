/*Copyright 2019-2023 Kai D. Gonzalez*/

module lexer;

import std.ascii : isAlpha, isDigit;

/** 
 * simple state for the lexer (use with LexState)
 */
enum f3lexerState
{
    STATE_START, // the start of an expression
    STATE_STRING, // the start of a string
    STATE_COMMENT, // the start of a comment
    STATE_INLINE, // inside of an inline statement
    STATE_DECL_NAME, // the name of a declaration fn [name ...]
    STATE_DECL_BODY, // the body of a declaration fn [name ...] { ... }
    STATE_FN_NAME, // the name of a function [name ...]
    STATE_FN_ARGS, // the arguments of a function [name] [args ...]
    STATE_END, // the end of a statement
}

/** 
 * the type of a character (usually tokens will come with this value)
 */
enum f3charType
{
    LETTER, // a letter
    DIGIT, // a digit
    WHITESPACE, // a whitespace
    SYMBOL, // a symbol
    COMMENT, // a comment start
    STRING, // a string
    NEWLINE, // a newline
    END, // the end of a statement
    DECL_BODY_BEGIN, // the start of a declaration body
    DECL_BODY_END, // the end of a declaration body
    INLINE_BEGIN, // the start of an inline statement ( [...] )
    INLINE_END, // the end of an inline statement ( [...] )
    UNKNOWN // an unknown character
}

/** 
 * ends a statement or enters a block depending on where a newline is placed.
 * (see also f3END)
 */
const char f3NEWLINE = '\n';

/** 
 * a whitespace to separate function names from their respective arguments
 */
const char f3WHITESPACE = ' ';

/**
 * the end of a statement (separate to f3NEWLINE, you can use multiple
 * statements on one line with f3END)
 */
const char f3END = ';';

/** 
 * the end of a declaration name (starting the body)
 */
const char f3STARTBODY = '{';

/** 
 * the end of a declaration body
 */
const char f3ENDBODY = '}';

/** 
 * start of an inline statement
 */
// e.g print [add 1 2]
const char f3INLINE_BEGIN = '[';

/** 
 * end of an inline statement
 */
// e.g print [add 1 2]
const char f3INLINE_END = ']';

/**
 * simple struct to keep track of a token
 */
struct LexToken
{
    // the token
    char tok;

    // the type of the token
    f3charType type;
}

/** 
 * simple struct to keep track of the place in a statement
 */
struct LexState
{
    uint place; // current character place in the actual statement
    uint line; // current line [\n]
    uint col; // current column (each character is one column)

    LexToken prev; // the previous token
    LexToken ptoken; // the current token

    f3lexerState state; // the current state

    string statement; // the statement being lexed
}

/** 
 * 
 * Params:
 *   t = the character to check
 * Returns: f3charType with type information about that specific character
 */
f3charType lex_token_type(char t)
{
    bool isSymbol(char c)
    {
        return c == '!' || c == '@' || c == '#'
            || c == '$' || c == '%' || c == '^'
            || c == '&' || c == '*' || c == '('
            || c == ')' || c == '-' || c == '_'
            || c == '+' || c == '=' || c == '['
            || c == ']' || c == '|' || c == '\\'
            || c == ',' || c == ';' || c == ':' 
            || c == '?';
    }

    switch (t)
    {
    case ' ':
        return f3charType.WHITESPACE;
    case '\n':
        return f3charType.NEWLINE;
    case ';':
        return f3charType.END;
    case '"':
        return f3charType.STRING;
    case '{':
        return f3charType.DECL_BODY_BEGIN;
    case '}':
        return f3charType.DECL_BODY_END;
    case '[':
        return f3charType.INLINE_BEGIN;
    case ']':
        return f3charType.INLINE_END;
    case '#':
        return f3charType.COMMENT;
    default:

        if (isSymbol(t)) /* is a symbol? (!, @, #) */
        {
            return f3charType.SYMBOL;
        }

        // additional checks
        if (isAlpha(t)) /* is a letter? (a-z) */
        {
            return f3charType.LETTER;
        }

        if (isDigit(t)) /* is a digit? (0-9) */
        {
            return f3charType.DIGIT;
        }

        return f3charType.UNKNOWN; /* unknown */
    }
}

/** 
 * Appends .tok and .type to a LexToken
 * Params:
 *   token = the token object
 *   tok = the token character
 */
void lex_token_create(LexToken* token, char tok)
{
    token.tok = tok; // setting the token and type
    token.type = lex_token_type(tok); // setting the type
}

/** 
 * Sets state object S new state to STATE
 * Params:
 *   s = the state object
 *   state = the state to change it's state to.
 */
void lex_set_state(LexState* s, f3lexerState state)
{
    s.state = state;
}

/**
 * Initializes a LexState
 * Params:
 *   state = the state object
 */
void lex_init(LexState* state, string statement)
{
    state.place = 0;
    state.line = 1;
    state.col = 0;

    lex_set_state(state, f3lexerState.STATE_START);

    state.statement = statement;

    state.ptoken = LexToken();
    state.prev = LexToken(); /* note: never set this under any circumstances */

    lex_token_create(&state.ptoken, state.statement[state.place]);
}

/**
 * Returns the next token (and also updates the last token and moves the place
 * forward 1)
 * Params:
 *   state = the state object
 * Returns: the next token
 */
LexToken lex_next(LexState* state)
{
    if (state.place >= state.statement.length - 1)
    { // why the hell are you going out of bounds
        return LexToken();
    }

    state.prev = state.ptoken;

    state.place++;
    state.col++;

    lex_token_create(&state.ptoken, state.statement[state.place]);

    if (state.ptoken.type == f3charType.NEWLINE)
    {
        state.line++;
        state.col = 0;
    }

    return state.ptoken;
}

/** 
 * why wasn't this documented before (function self-explanatory)
 */
LexToken lex_current_token(LexState* state)
{
    return state.ptoken;
}

/** 
 * Returns the current state
 * Params:
 *   state = the state object
 * Returns: the current state
 */
f3lexerState lex_get_state(LexState* state)
{
    return state.state;
}

/** 
 * Returns the current token
 * Params:
 *   state = the state object
 * Returns: the current token
 */
LexToken lex_get_token(LexState* state)
{
    return state.ptoken;
}

/** 
 * Returns the current line
 * Params:
 *   state = the state object
 * Returns: the current line
 */
uint lex_get_line(LexState* state)
{
    return state.line;
}

/** 
 * Returns the current column
 * Params:
 *   state = the state object
 * Returns: the current column
 */
uint lex_get_col(LexState* state)
{
    return state.col;
}

bool lex_eof(LexState* state)
{
    return state.place >= state.statement.length - 1;
}

string lex_token_tostring(LexToken token)
{
    switch (token.type)
    {
    case f3charType.LETTER:
        return "f3letter";
    case f3charType.DIGIT:
        return "f3digit";
    case f3charType.WHITESPACE:
        return "f3whitespace";
    case f3charType.NEWLINE:
        return "f3newline";
    case f3charType.SYMBOL:
        return "f3symbol";
    case f3charType.STRING:
        return "f3string";
    case f3charType.COMMENT:
        return "f3comment";
    case f3charType.DECL_BODY_BEGIN:
        return "f3decl_body_begin";
    case f3charType.DECL_BODY_END:
        return "f3decl_body_end";
    case f3charType.END:
        return "f3end";
    case f3charType.INLINE_BEGIN:
        return "f3inline_begin";
    case f3charType.INLINE_END:
        return "f3inline_end";
    case f3charType.UNKNOWN:
        return "f3unknown";
    default:
        return "f3unknown";
    }
}
