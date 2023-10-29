module parser;

import lexer;
import errors;

import std.stdio : writefln;
import std.string : strip, endsWith;
import std.ascii : isAlpha, isDigit;
import std.conv : to;

// parses statements

enum ASTNodeType
{
    ASTDecl,
    ASTFn,
    ASTValue,
    ASTExpr,
    ASTCall
}

enum ASTValueType
{
    ASTString,
    ASTNumber,
    ASTBool,
    ASTFunc
}

struct ASTValue
{
    string value;
    ASTValueType type;
    string[] arg;
}

/** 
 * A node in the AST, this keeps track of the id, type, and next lines of code
 */
struct ASTNode
{
    /** 
     * the id of the node (fn, print, etc.)
     */
    string id;

    /**
     * the arguments of the node *(these are different from inline statements,
     * these are converted to values at runtime)*
     */
    string[] arg;

    /**
     * the type of the node (see ASTNodeType)
     */
    ASTNodeType type;

    /**
     * For example, if you have a declaration and you have statements inside of
     * it they will be called the "next" statements
     */
    AST[] next;
}

/** 
 * a simple AST.
 *
 * each AST contains an array of nodes, which hold ids, types, and next
 * references
 */
struct AST
{
    /**
        This holds ASTNodes, each node has properties like next, id, and type.
     */
    ASTNode[] node;
}

/** 
 * Parses the braces as long as they're matching in the lexer's statement.
 * (NOTE: this renders the Lexer unusable unless you reset it's statement values
 * afterward, for a quick solution use `parse_matching_braces`)
 * Params:
 *   s = the lexer
 * Returns: a string that contains the parsed statements
 */
string pars_matching_braces(LexState* s)
{
    string result = "";

    int depth = 0;

    /* NOTE: i will most likely copy this algorithm to other parsers/lexers */

    while (!lex_eof(s))
    {
        if (lex_get_token(s).tok == '{' && lex_get_state(s) == f3lexerState.STATE_START && depth == 0
            )
        {
            s.state = f3lexerState.STATE_DECL_BODY;
            depth++;
        }

        else if (lex_get_token(s).tok == '}' && lex_get_state(s) == f3lexerState.STATE_DECL_BODY && depth == 1)
        {
            s.state = f3lexerState.STATE_END;

            depth = 0;

            break;
        }

        else if (lex_get_token(s).tok == '{' && lex_get_state(s) == f3lexerState.STATE_DECL_BODY && depth > 0)
        {
            depth++;

            goto add;
        }

        else if (lex_get_token(s).tok == '}' && lex_get_state(s) == f3lexerState.STATE_DECL_BODY && depth > 1)
        {
            depth--;
            goto add;
        }
        else
        {
        add:
            if (depth > 0)
                result ~= lex_get_token(s).tok;
        }

        lex_next(s);
    }

    if (depth > 1 || depth < 0)
        error([], "F3UnbalancedBracesException");

    return strip(result);
}

/** 
 * Parses the matching braces of a statement and returns the information inside them
 * Params:
 *   statement = the statement to parse
 * Returns: a string that contains the information inside the nearest matching braces
 */
string parse_matching_braces(string statement)
{
    LexState s;
    lex_init(&s, statement);
    return pars_matching_braces(&s);
}

/** 
 * Creates a node and returns it
 * Params:
 *   type = the type of the node
 *   id = the id of the node
 */
ASTNode ast_create_node(ASTNodeType type, string id)
{
    ASTNode n;

    n.type = type;
    n.id = id;

    return n;
}

/**
 * Adds a node to the AST
 * Params:
 *   ast = the AST to add the node to
 *   n = the node to add
 */
void ast_add_node(AST* ast, ASTNode n)
{
    ast.node ~= n;
}

/** 
 * adds the next of a node
 * Params: 
 *   node = the node to set the next of
 */
void ast_set_next(ASTNode* node, AST next)
{
    node.next ~= next;
}

/** 
 * Returns an AST from statement
 *
 * This AST will recursively parse the statement, meaning that any substatements
 * will also be parsed.
 * Params:
 *   statement = the statement to parse
 * Returns: a recursively parsed AST
 */
AST generate_ast(string statement)
{
    LexState s;
    lex_init(&s, statement);

    statement ~= '\n';

    AST ast;

    ASTNode current;

    f3lexerState prev;

    string tmp = "";

    int depth = 0;
    int i = 0;

    LexToken t;
    s.line = 1;
    s.col = 1;
    /**
        to ensure the last character is actually noted
    */
    while (!lex_eof(&s) || t != LexToken())
    {
        s.col++;
        auto token = lex_get_token(&s);
        auto state = lex_get_state(&s);

        t = lex_next(&s); // keeping track of the current and the next character

        if (token.type == f3charType.NEWLINE)
        {
            s.line++;
            s.col = 0;
        }

        if ((token.type == f3charType.WHITESPACE || token.type == f3charType.NEWLINE) &&
            state == f3lexerState.STATE_START && strip(tmp).length > 0 && state != f3lexerState
            .STATE_COMMENT) /* [fn ...] */
        {
            // thank you to my wife, miranda. for keeping
            // me sane and being an amazing wife
            

            // we always have to strip whitespaces from the temporary buffer
            // before doing anything else. to prevent any ugly ass names i will
            // never fix
            tmp = strip(tmp);

            // using switch statements because they look better and are faster
            switch (tmp)
            {
            case "fn":
                current.id = tmp;
                current.type = ASTNodeType.ASTDecl;

                lex_set_state(&s, f3lexerState.STATE_DECL_NAME);

                tmp = "";
                break;

            default:
                current.id = tmp;
                current.type = ASTNodeType.ASTCall;

                lex_set_state(&s, f3lexerState.STATE_FN_ARGS);

                tmp = "";
                break;
            }
        }
        else if (token.type == f3charType.DECL_BODY_BEGIN
            && state == f3lexerState.STATE_DECL_NAME) /* fn [name ...] { ... } */
        {
            current.arg ~= strip(tmp);
            tmp = "";
            depth = 1;
            s.state = f3lexerState.STATE_DECL_BODY;
        }

        else if (token.type == f3charType.DECL_BODY_END &&
            depth == 1 && state == f3lexerState.STATE_DECL_BODY) /* fn [name ...] { ... } */
        {
            current.next ~= generate_ast(tmp);

            ast_add_node(&ast, current);

            current = ASTNode();
            tmp = "";
            s.state = f3lexerState.STATE_START;
            depth = 0;
        }

        else if (token.type == f3charType.INLINE_BEGIN && state == f3lexerState.STATE_FN_ARGS)
        {
            s.state = f3lexerState.STATE_INLINE;
            depth++;
            goto c;

        }

        else if (token.type == f3charType.INLINE_END
            && state == f3lexerState.STATE_INLINE && depth == 1)
        {
            depth = 0;
            s.state = f3lexerState.STATE_FN_ARGS;
            goto c;

        }

        else if (token.type == f3charType.INLINE_BEGIN && state == f3lexerState.STATE_FN_ARGS)
        {
            depth++;
            goto c;

        }

        else if (token.type == f3charType.INLINE_END && state == f3lexerState.STATE_INLINE)
        {
            depth--;
            goto c;
        }

        else if (token.type == f3charType.STRING && state == f3lexerState.STATE_FN_ARGS)
        {
            s.state = f3lexerState.STATE_STRING;
            tmp ~= token.tok;
        }

        else if (token.type == f3charType.STRING && state == f3lexerState.STATE_STRING)
        {
            s.state = f3lexerState.STATE_FN_ARGS;
            tmp ~= token.tok;

        }

        else if (token.type == f3charType.WHITESPACE && state == f3lexerState.STATE_FN_ARGS)
        {
            current.arg ~= strip(tmp);

            tmp = "";
        }
        else if (token.type == f3charType.DECL_BODY_BEGIN
            && state == f3lexerState.STATE_DECL_BODY
            && state != f3lexerState.STATE_COMMENT) /* { { ... } } */
        {
            depth++;
            goto c;
        }

        else if (token.type == f3charType.DECL_BODY_END
            && state == f3lexerState.STATE_DECL_BODY
            && state != f3lexerState.STATE_COMMENT)
        {
            depth--;
            goto c;
        }

        else if (token.type == f3charType.END && state == f3lexerState.STATE_FN_ARGS)
        {
            current.arg ~= strip(tmp);

            ast_add_node(&ast, current);
            s.state = f3lexerState.STATE_START;

            current = ASTNode();
            tmp = "";
        }

        else if (token.type == f3charType.COMMENT && state != f3lexerState.STATE_STRING)
        {
            prev = s.state;
            s.state = f3lexerState.STATE_COMMENT;

            tmp = "";
        }

        else if (token.type == f3charType.NEWLINE && state == f3lexerState.STATE_COMMENT)
        {
            s.state = prev;
            tmp = "";
        }

        else if (token.type == f3charType.END && state == f3lexerState.STATE_START)
        {
            current.id = strip(tmp);
            current.type = ASTNodeType.ASTCall;

            ast_add_node(&ast, current);

            s.state = f3lexerState.STATE_START;
            current = ASTNode();
            tmp = "";
        }

        else if (token.type == f3charType.NEWLINE && state == f3lexerState.STATE_FN_ARGS)
        {
            writefln("\x1b[31;1mfun3(%d:%d)\x1b[0m: expected ';'\n\tnear:\n\t\t\x1b[32;3m%s\x1b[0m", s.line, s.col, tmp);
            writefln(
                "\x1b[31;3mfun3: note: newline-separated statements are not supported in fun3\x1b[0m");
            error([], "F3MissingSemicolonException");
        }

        else
        {
            if (state == f3lexerState.STATE_COMMENT)
            {
                continue;
            }
        c:
            if (state != f3lexerState.STATE_STRING
                || state != f3lexerState.STATE_COMMENT)
            {
                if (!isAlpha(token.tok) && !isDigit(token.tok) && token.type == f3charType.UNKNOWN)
                {
                    writefln(
                        "\x1b[31;1mfun3(%d:%d)\x1b[0m: unexpected token: %s\t%s('%c')",
                        s.line, s.col, token.tok, tmp, token.tok);
                    writefln("\x1b[31;3mfun3: note: where ('TOKEN') is the faulty token\x1b[0m");
                    error([to!string(token.tok)], "F3UnexpectedTokenException", token.tok);
                }
            }
            tmp ~= token.tok;
        }

        i++;
    }

    if (depth > 0)
    {
        writefln("\x1b[31;1mfun3(%d:%d)\x1b[0m: unbalanced braces", s.line, s.col);
        error([], "F3UnbalancedBracesException");
    }

    if (tmp.length > 0)
    {
        // goto add;
    }

    return ast;
}

void print_ast_array(AST[] t)
{
    foreach (AST n; t)
    {
        writefln(":=== NODE SUB ===:");
        foreach (ASTNode node; n.node)
        {
            writefln("ASTNODE TYPE: %s", node.type);
            writefln("ASTNODE ID: %s", node.id);
            writefln("ASTNODE ARGS: %s", node.arg);
            print_ast_array(node.next);
        }
    }
}

/**
* recursively print an AST
*/
void print_ast(AST t)
{
    foreach (ASTNode n; t.node)
    {
        writefln("ASTNODE TYPE: %s", n.type);
        writefln("ASTNODE ID: %s", n.id);
        writefln("ASTNODE ARGS: %s", n.arg);
        print_ast_array(n.next);
        writefln(":=============:");

    }
}
