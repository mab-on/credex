# credex
Keep database credentials outside the sourcecode

This library makes it easy to load credentials from external files and use it for database clients.
It was build with MySQL/MariaDB in mind - but it can surely be used for similar credential structures.

## The credential file
The format of the file, which stores the information is very simple and ini-like
```ini
# this is a comment
; this is a comment

[connection_name]
host = 127.0.0.1
port = 3306
user = MyUser
pwd = MyPassword
db = MyDatabase

[2nd test connection]
host = localhost
user = some_user
pwd = 1234
```

## Usage
```D
Credential[] credentials = .load("./source/test.cred");
assert(credentials.length == 3);

assert(credentials.get("connection_name").connectionName == "connection_name");
assert(credentials.get("connection_name").host == "127.0.0.1");
assert(credentials.get("connection_name").port == 3306);
assert(credentials.get("connection_name").user == "MyUser");
assert(credentials.get("connection_name").pwd == "MyPassword");
assert(credentials.get("connection_name").db == "MyDatabase");
assert(credentials.get("connection_name").connectionString == "host=127.0.0.1;port=3306;user=MyUser;pwd=MyPassword;db=MyDatabase");
```
```D
Credential _2ndTestCred = .load("./source/test.cred").get("2nd test connection");

assert(_2ndTestCred.connectionName == "2nd test connection" );
assert(_2ndTestCred.connectionString == "host=localhost;user=some_user;pwd=1234" );
assert(_2ndTestCred.host == "localhost" );
assert(_2ndTestCred.user == "some_user" );
assert(_2ndTestCred.pwd == "1234" );
assert(_2ndTestCred.port.isNull );
assert(_2ndTestCred.db.isNull );
```
