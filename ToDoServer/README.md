# ToDoServer Component

### PersistentiOSKituraKit
The server component from [iOSSampleKituraKit](https://github.com/IBM-Swift/iOSSampleKituraKit/tree/master/ToDoServer) has been adapted to store data in a mySQL database so even if the server is restarted the data is stored and will persist.

### File Structure

The file structure matches what would be automatically generated using `kitura init`. This scaffold contains a few key files, along with a load of extras to help start any project as easily as possible. 

#### Sources

This folder contains the running programs files. It is split into /Application and /ToDoServer. The second folder matches the name of the project and is where main.swift is stored. This runs the application, and the /Application folder contains the Classes and Models that are used in the running application.

### Application.swift

This is where the majority of logic regarding the server lives. It defines routes available for the server, starts the server using `Kitura.run()` and also sets up handlers for a manner **RESTful requests**. The context of the request is inferred by a combination of the type of request (post, put, patch, delete or get) and the parameters given. The majority of the file is the handlers, there is also some environment setup at the start of the file for SwiftMetrics and Health. If you choose to include SwiftMetrics, navigating to https://localhost:8080/swiftmetrics-dash will show the servers activity as a live Dashboard.

Swift Kuery and SwiftKueryMySQL are imported
```
import SwiftKuery
import SwiftKueryMySQL
```
create and instance of your The ToDoTable class
```
let todotable = ToDoTable()
```
We connect to the database
`    let connection = MySQLConnection(user: "swift", password: "kuery", database: "ToDoDatabase", port: 3306)`
Handlers for server routes are ajusted to take data from the database. E.G. create handler:

```
func createHandler(todo: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void ) -> Void {
    var todo = todo
    if todo.completed == nil {
        todo.completed = false
    }
    todo.id = getNextId()
    guard let id = todo.id else {return}
    todo.url = "http://localhost:8080/\(id)"
    connection.connect() { error in
        if error != nil {
            print("connection error: \(String(describing: error))")
            completion(nil, .internalServerError)
            return
        }
    guard let title = todo.title, let user = todo.user, let order = todo.order, let completed = todo.completed, let url = todo.url else {
        print("assigning todo error: \(todo)")
        return
    }
    let insertQuery = Insert(into: todotable, values: [id, title, user, order, completed, url])
    connection.execute(query: insertQuery) { result in
        if !result.success {
            if let queryError = result.asError {
                // Something went wrong.
                print("insert query error: \(queryError)")
                }
    completion(nil, .internalServerError)
    return
    }
}
}
completion(todo, nil)
}
```

### Package.swift

This file works with Swift Package Manager, and gets remote repos and projects for you to use in your projects. It's contents for this app are typical, and its syntax is clear when dependencies. However, note that the targets must match **directory names** and then define all that folders files dependencies, or an empty array if it has no dependencies.

To use MySQL SwiftKueryMySQL and Swift-Kuery have been added to the list of packages

```
.package(url: "https://github.com/IBM-Swift/SwiftKueryMySQL.git", .upToNextMinor(from: "1.0.0")),
.package(url: "https://github.com/IBM-Swift/Swift-Kuery.git", .upToNextMinor(from: "0.13.0")),
```
They are then added to the targets for ToDoServer and Application
```
.target(name: "ToDoServer", dependencies: [ .target(name: "Application"), "Kitura" , "HeliumLogger", "SwiftKuery", "SwiftKueryMySQL"]),
.target(name: "Application", dependencies: [ "Kitura", "KituraCORS", "CloudEnvironment", "Health" , "SwiftMetrics", "SwiftKuery", "SwiftKueryMySQL"]),
```

### Models.swift

inside Models we create a class matching the database table

```
public class ToDoTable : Table {
    let tableName = "toDoTable"
    let toDo_id = Column("toDo_id")
    let toDo_title = Column("toDo_title")
    let toDo_user = Column("toDo_user")
    let toDo_order = Column("toDo_order")
    let toDo_completed = Column("toDo_completed")
    let toDo_url = Column("toDo_url")
}
```

### Main.swift

This simple file starts logging with HeliumLogger, and then creates an instance of the Application object before calling its run method. The running never halts as the server is always waiting for new connections and requests. Therefore any terminal window it runs in will be unable to repsond to new inputs, so opening a new window is needed for new commands. 

**HINT:** To cancel a running process in a terminal window, press CTRL + C.

### Switching to PostgreSQL
1. Start the postgreSQL database"

`brew install postgresql`

2. Create a database and open postgreSQL command line:

`createdb ToDoDatabase`
`psql ToDoDatabase`

3. Create a ToDo item table:

```
CREATE TABLE toDoTable (
toDo_id integer primary key,
toDo_title varchar(50),
toDo_user varchar(50),
toDo_order integer,
toDo_completed boolean,
toDo_url varchar(50)
);
```

4. change Package.swift by uncommenting Swift-Kuery-PostgreSQL and Swift-Kuery and the targets and commenting out SwiftKueryMySQL and Swift-Kuery version 0.13.0 and targets including SwiftKueryMySQL

5. in models uncomment import SwiftKueryPostgreSQL and comment import SwiftKueryMySQL

6. in Application.swift file uncomment import SwiftKueryPostgreSQL and comment import SwiftKueryMySQL and change the connection to:
`let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("ToDoDatabase")])`

Now when you run the server it will connect to your postgreSQL database.

### Metrics.swift, InitializationError.swift, and Routes/HealthRoutes.swift

These files provide logging and metrics for the running application. Health provied a succinct UP message in the browser window as JSON if a user navigates to http://localhost:8080/health. 

### Further Reading and Resources

https://docker.com

https://kitura.io

https://developer.apple.com/swift
