module mycreds;

import std.typecons : Nullable;

struct Credential {
    string host;
    Nullable!ushort port;
    string user;
    Nullable!string pwd;
    Nullable!string db;
    string connectionName;

    @property string connectionString()
    {
        import std.conv : to;
        return 
            "host="~this.host~";"
            ~ "port="~ (this.port.isNull ? "3306" : this.port.to!string) ~";"
            ~"user="~this.user~";"
            ~ (this.pwd.isNull ? "" : "pwd="~this.pwd~";")
            ~ (this.db.isNull ? "" : "db="~this.db~";");
    }

    string toString()
    {
        return this.connectionString;
    }
}

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
    
    immutable string FERR_OBLIGATORY_PARAMS = "'host' or 'user' variable is missing for Credential '%s'";

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
                if(credential.host == credential.host.init || credential.user == credential.user.init)
                {
                    throw new CredentialsException(format(FERR_OBLIGATORY_PARAMS , credential.connectionName ));
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
                    throw new CredentialsException( format( "The Credential Entity Name must be unique ('%s')" , nameCapture[1].toLower ) );
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
                        throw new CredentialsException(format("Multiple definitions for '%s' in '%s'" ,  variableCapture[1].toLower,  credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialsException(format("variable '%s' cannot be empty at line '%s:%d'" , variableCapture[1].toLower , file , 1+file_lineno) );

                    credential.host = variableCapture[2];
                    break;

                case "port":
                    if( ! credential.port.isNull)
                        throw new CredentialsException(format("Multiple definitions for port in '%s'" , credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialsException(format("if '%s' is given, it cannot be empty at line '%s:%d'" , variableCapture[1].toLower , file ,  1+file_lineno) );

                    try {
                        credential.port = variableCapture[2].to!ushort;
                    }
                    catch( ConvException e )
                    {
                        throw new CredentialsException(format( "port must have a value between %d and %d in '%s:%d'" , credential.port.min , credential.port.max , file , 1+file_lineno ));
                    }
                    break;

                case "user":
                    if(credential.user.length)
                        throw new CredentialsException(format("Multiple definitions for user in '%s'" , credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialsException(format("apply a non empty value to '%s' or leave it completely in '%s:%d'" , variableCapture[1].toLower , file ,  1+file_lineno) );

                    credential.user = variableCapture[2];
                    break;

                case "pwd":
                    if( ! credential.pwd.isNull )
                        throw new CredentialsException(format("Multiple definitions for pwd in '%s'" , credential.connectionName) );
                    if( ! variableCapture[2].length)
                        throw new CredentialsException(format("apply a non empty value to '%s' or leave it completely in '%s:%d'" , variableCapture[1].toLower , file ,  1+file_lineno) );

                    credential.pwd = variableCapture[2];
                    break;

                case "db":
                    if( ! credential.db.isNull )
                        throw new CredentialsException(format("Multiple definitions for db in '%s'" , credential.connectionName) );
                    credential.db = variableCapture[2];
                    break;

                default:
                    throw new CredentialsException(format("unknown variable  in '%s:%d'" , file , 1+file_lineno) );
            }
        }

        if(
            nameCapture.empty
            && variableCapture.empty
            && false == line.startsWith("#",";")
            && line.strip.length
        ) {
            throw new CredentialsException(format("Syntax Error at line %d" , 1+file_lineno) );
        }

    }

    /*
    * Handle the last Credential Entity
    * Check if all obligatory parameters are given
    */
    if(
        credential.connectionName != credential.connectionName.init
        && (credential.host == credential.host.init || credential.user == credential.user.init)
    ) {
        throw new CredentialsException(format(FERR_OBLIGATORY_PARAMS , credential.connectionName ));
    }
    else
    {
        credentials ~= credential;
    }
    
    return credentials;
}
unittest {
    auto credentials = .load("./source/test.cred");
    assert(credentials.length = 3);

}

class CredentialsException : Exception
{
    this(string msg) { super(msg); }
}