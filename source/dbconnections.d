/**
* Store database credentials outside the sourcecode
*
* This module makes it easy to load credentials from external files and use it for Database Clients.
* This module was build with MySQL/MariaDB credentials in mind - but it can surely be used for similar credential structures.
*
* Authors: Martin Brzenska
' Licence: MIT
*
*/
module dbconnections;

import std.typecons : Nullable;

/**
* Holds credentials used for a login
*
* Authors: Martin Brzenska
' Licence: MIT
*/
struct Credential
{
    private string __host;
    private Nullable!ushort __port;
    private Nullable!string __user;
    private Nullable!string __pwd;
    private Nullable!string __db;
    private string __connectionName;

    public:
        ///
        @property Credential host(string host)
        {
            this.__host = host;
            return this;
        }
        ///
        @property string host() { return this.__host; }

        ///
        @property Credential port(ushort port)
        {
            import std.conv : to;
            this.__port = port;
            return this;
        }
        Nullable!ushort port() @property
        { return this.__port; }
        ///
        @property Credential user(string user)
        {
            this.__user = user;
            return this;
        }
        ///
        @property Nullable!string user() { return this.__user; }

        ///
        @property Credential pwd(string pwd)
        {
            this.__pwd = pwd;
            return this;
        }
        ///
        @property Nullable!string pwd() { return this.__pwd; }

        ///
        @property Credential db(string db)
        {
            this.__db = db;
            return this;
        }
        ///
        @property Nullable!string db() { return this.__db; }

        ///
        @property Credential connectionName(string connectionName)
        {
            this.__connectionName = connectionName;
            return this;
        }
        ///
        const string connectionName() @property { return this.__connectionName; }

        ///
        @property string connectionString()
        {
            import std.conv : to;
            import std.string : chop;
            return
                chop(
                    "host="~this.host~";"
                    ~ (this.port.isNull ? "" : "port="~this.port.to!string~";")
                    ~ (this.user.isNull ? "" : "user="~this.user~";")
                    ~ (this.pwd.isNull ? "" : "pwd="~this.pwd~";")
                    ~ (this.db.isNull ? "" : "db="~this.db~";")
                );
        }
    ///
    unittest
    {
        auto cred = Credential().host("localhost");
        assert(cred.connectionString == "host=localhost");

        cred = Credential().host("127.0.0.1").port(3306);
        assert(cred.connectionString == "host=127.0.0.1;port=3306");

        cred = Credential().host("localhost").user("testuser").db("SchemaXY");
        assert(cred.connectionString == "host=localhost;user=testuser;db=SchemaXY");
        assert(cred.host == "localhost");

    }

    string toString()
    {
        return this.connectionString;
    }
}

/**
* Loads credentials from the given file
*
* The file to load must have the appropriate format (see example below).
* One file can hold multiple credential entities, each consisting of a name and a set of variables.
*
* Examples:
* -----------------
* [connection_name]
* host = 127.0.0.1
* port = 3306
* user = MyUser
* pwd = MyPassword
* db = MyDatabase
* -----------------
*
* Throws: CredentialException if file is not formated as expected
* Throws: ErrnoException if file could not be opened.
*
* Authors: Martin Brzenska
' Licence: MIT
*
*/
public Credential[] load(string file)
{
    import std.algorithm.searching : maxElement , startsWith;
    import std.array : array;
    import std.format : format;
    import std.regex;
    import std.stdio : File;
    import std.string : strip;
    import std.uni : toLower;
    import std.conv : to , ConvOverflowException , ConvException;

    auto connectionName = ctRegex!(`^[\s]*\[([^\]]+)\][\s]*$`);
    auto variable = ctRegex!(`^[\s]*(host|port|user|pwd|db)[\s]*=[\s]*(.*)[\s]*$`);

    immutable string FERR_OBLIGATORY_PARAMS = "'host' variable is missing for Credential '%s'";

    Credential[] credentials;

    /*
    * is temporarily used to build up a Credential Entity
    */
    Credential credential;

    foreach( file_lineno , line ; File(file).byLineCopy.array )
    {
        auto nameCapture = line.matchFirst(connectionName);
        if( ! nameCapture.empty )
        {
            /*
            * This is the beginning of a new connection
            */

            if(credential.connectionName != credential.connectionName.init)
            {
                /*
                * If there was a connection before, make sure that all obligatory variables from the previous credentialEntity are set.
                * If ok, add the previous entity to the result array.
                */
                if(credential.host == credential.host.init)
                {
                    throw new CredentialException(format(FERR_OBLIGATORY_PARAMS , credential.connectionName ));
                }
                else
                {
                    credentials ~= credential;
                }
            }

            /*
            * Check if we already had a connection with this name
            */
            foreach( cred ; credentials )
            {
                if( cred.connectionName == nameCapture[1].toLower )
                {
                    throw new CredentialException( format( "The Credential Entity Name must be unique ('%s')" , nameCapture[1].toLower ) );
                }
            }

            credential = Credential();
            credential.connectionName = nameCapture[1].toLower;
        }

        auto variableCapture = line.matchFirst(variable);
        if( ! variableCapture.empty )
        {
            switch(variableCapture[1].toLower)
            {
                case "host":
                    if(credential.host.length)
                        throw new CredentialException(format("Multiple definitions for '%s' in '%s'" ,  variableCapture[1].toLower,  credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialException(format("variable '%s' cannot be empty at line '%s:%d'" , variableCapture[1].toLower , file , 1+file_lineno) );

                    credential.host = variableCapture[2];
                    break;

                case "port":
                    if( ! credential.port.isNull)
                        throw new CredentialException(format("Multiple definitions for port in '%s'" , credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialException(format("if '%s' is given, it cannot be empty at line '%s:%d'" , variableCapture[1].toLower , file ,  1+file_lineno) );

                    try {
                        credential.port = variableCapture[2].to!ushort;
                    }
                    catch( ConvException e )
                    {
                        throw new CredentialException(format( "port must have a value between %d and %d in '%s:%d'" , credential.port.min , credential.port.max , file , 1+file_lineno ));
                    }
                    break;

                case "user":
                    if( ! credential.user.isNull)
                        throw new CredentialException(format("Multiple definitions for user in '%s'" , credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialException(format("apply a non empty value to '%s' or leave it completely in '%s:%d'" , variableCapture[1].toLower , file ,  1+file_lineno) );

                    credential.user = variableCapture[2];
                    break;

                case "pwd":
                    if( ! credential.pwd.isNull )
                        throw new CredentialException(format("Multiple definitions for pwd in '%s'" , credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialException(format("apply a non empty value to '%s' or leave it completely in '%s:%d'" , variableCapture[1].toLower , file ,  1+file_lineno) );

                    credential.pwd = variableCapture[2];
                    break;

                case "db":
                    if( ! credential.db.isNull )
                        throw new CredentialException(format("Multiple definitions for db in '%s'" , credential.connectionName) );
                    credential.db = variableCapture[2];
                    break;

                default:
                    throw new CredentialException(format("unknown variable  in '%s:%d'" , file , 1+file_lineno) );
            }
        }

        if(
            nameCapture.empty
            && variableCapture.empty
            && false == line.startsWith("#",";")
            && line.strip.length
        ) {
            throw new CredentialException(format("Syntax Error at line %d" , 1+file_lineno) );
        }
    }

    /*
    * Handle the last Credential Entity
    * Check if all obligatory parameters are given
    */
    if(
        credential.connectionName != credential.connectionName.init
        && credential.host == credential.host.init
    ) {
        throw new CredentialException(format(FERR_OBLIGATORY_PARAMS , credential.connectionName ));
    }
    else
    {
        credentials ~= credential;
    }

    return credentials;
}
///
unittest {
    auto credentials = .load("./source/test.cred");
    assert(credentials.length == 3);

    assert(credentials[0].connectionName == "connection_name");
    assert(credentials[0].host == "127.0.0.1");
    assert(credentials[0].port == 3306);
    assert(credentials[0].connectionString == "host=127.0.0.1;port=3306;user=MyUser;pwd=MyPassword;db=MyDatabase");
}

/**
* Gets the Credential entity with the given name
*
* Throws: core.exception.RangeError if name cannot be found
*
* Authors: Martin Brzenska
' Licence: MIT
*/
Credential get(in Credential[] credentials , string name )
{
    import std.algorithm.searching : countUntil;
    return credentials[ credentials.countUntil!(cred => cred.connectionName == name) ];
}
unittest
{
    auto credentials = .load("./source/test.cred");
    assert(credentials.get("connection_name").connectionName == "connection_name");
}

class CredentialException : Exception
{
    this(string msg) { super(msg); }
}