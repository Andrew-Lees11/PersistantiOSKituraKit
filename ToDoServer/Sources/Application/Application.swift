/*
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Kitura
import KituraCORS
import Foundation
import KituraContracts
import LoggerAPI
import Configuration
import CloudEnvironment
import Health
import SwiftKuery
import SwiftKueryPostgreSQL

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()
public var port: Int = 8080

public class Application {
    
    let router = Router()
    let cloudEnv = CloudEnv()
    let todotable = ToDoTable()
    let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("ToDoDatabase")])
    var todoStore = [ToDo]()
    var nextId :Int = 0
    
    func postInit() throws{
        // Capabilities
        initializeMetrics(app: self)
        
        let options = Options(allowedOrigin: .all)
        let cors = CORS(options: options)
        router.all("/*", middleware: cors)
        
        // Endpoints
        initializeHealthRoutes(app: self)
        
        // ToDoListBackend Routes
        router.post("/", handler: createHandler)
        router.get("/", handler: getAllHandler)
        router.get("/", handler: getOneHandler)
        router.delete("/", handler: deleteAllHandler)
        router.delete("/", handler: deleteOneHandler)
        router.patch("/", handler: updateHandler)
        router.put("/", handler: updatePutHandler)
        
    }
    
    
    public init() throws {
        // Configuration
        port = cloudEnv.port
    }
    
    public func run() throws{
        try postInit()
        Kitura.addHTTPServer(onPort: port, with: router)
        Kitura.run()
    }
    
    func createHandler(todo: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void ) -> Void {
        print("entered create handler")
        var todo = todo
        if todo.completed == nil {
            todo.completed = false
        }
        todo.id = getNextId()
        guard let id = todo.id else {return}
        todo.url = "http://localhost:8080/\(id)"
        connection.connect() { error in
            print("create connected")
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
        todoStore.append(todo)
        completion(todo, nil)
    }
    
    func getAllHandler(completion: @escaping ([ToDo]?, RequestError?) -> Void ) -> Void {
        var tempToDoStore = [ToDo]()
        connection.connect() { error in
            if error != nil {
                print("connection error: \(String(describing: error))")
                return
            }
            else {
                let selectQuery = Select(from :todotable)
                connection.execute(query: selectQuery) { queryResult in
                    if let resultSet = queryResult.asResultSet {
                        if !queryResult.success {
                            if let queryError = queryResult.asError {
                                // Something went wrong.
                                print("select query error: \(queryError)")
                            }
                            completion(nil, .internalServerError)
                            return
                            
                        }
                        for row in resultSet.rows {
                            print("inside rows")
                            guard let id = row[0], let idInt = id as? Int else{return}
                            guard let title = row[1], let titleString = title as? String else {return}
                            guard let user = row[2], let userString = user as? String else {return}
                            guard let order = row[3], let orderInt = order as? Int else {return}
                            guard let completed = row[4], let completedBool = completed as? Bool else {return}
                            guard let url = row[5], let urlString = url as? String else {return}
                            print("assigned values")
                           let currentToDo = ToDo(id: idInt, title: titleString, user: userString, order: orderInt, completed: completedBool, url: urlString)
                            print("made todo: \(currentToDo)")
                            tempToDoStore.append(currentToDo)
                        }
                    }
                    else if let queryError = queryResult.asError {
                        // Something went wrong.
                        print("Something went wrong \(queryError)")
                    }
                }
            }
        }
        self.todoStore = tempToDoStore
        completion(todoStore, nil)
    }
    
    func getOneHandler(id: Int, completion: (ToDo?, RequestError?) -> Void ) -> Void {
        guard let idMatch = todoStore.first(where: { $0.id == id }), let idPosition = todoStore.index(of: idMatch) else {
            completion(nil, .notFound)
            return
        }
        completion(todoStore[idPosition], nil)
    }
    
    func deleteAllHandler(completion: (RequestError?) -> Void ) -> Void {
        todoStore = [ToDo]()
        completion(nil)
    }
    
    func deleteOneHandler(id: Int, completion: (RequestError?) -> Void ) -> Void {
        guard let idMatch = todoStore.first(where: { $0.id == id }), let idPosition = todoStore.index(of: idMatch) else {
            completion(.notFound)
            return
        }
        todoStore.remove(at: idPosition)
        completion(nil)
    }
    
    func updateHandler(id: Int, new: ToDo, completion: (ToDo?, RequestError?) -> Void ) -> Void {
        guard let idMatch = todoStore.first(where: { $0.id == id }), let idPosition = todoStore.index(of: idMatch) else {
            completion(nil, .notFound)
            return
        }
        var current = todoStore[idPosition]
        current.user = new.user ?? current.user
        current.order = new.order ?? current.order
        current.title = new.title ?? current.title
        current.completed = new.completed ?? current.completed
        todoStore[idPosition] = current
        completion(todoStore[idPosition], nil)
    }
    
    func updatePutHandler(id: Int, new: ToDo, completion: (ToDo?, RequestError?) -> Void ) -> Void {
        guard let idMatch = todoStore.first(where: { $0.id == id }), let idPosition = todoStore.index(of: idMatch) else {
            completion(nil, .notFound)
            return
        }
        var current = todoStore[idPosition]
        current.user = new.user
        current.order = new.order
        current.title = new.title
        current.completed = new.completed
        todoStore[idPosition] = current
        completion(todoStore[idPosition], nil)
    }
    
    private func getNextId() -> Int {
        print("entered next id")
        var nextId = 997
        connection.connect() { error in
            print("connected next id")
            if error != nil {
                print("get id connection error")
                return
            }
            let maxIdQuery = Select(max(todotable.toDo_id) ,from: todotable)
            connection.execute(query: maxIdQuery) { queryResult in
                print("entered execute: \(queryResult)")
                if let resultSet = queryResult.asResultSet {
                    for row in resultSet.rows {
                        guard let id = row[0] else{return}
                        guard let id32 = id as? Int32 else{
                            print("id failed = int32: \(id)")
                            return
                        }
                        let idInt = Int(id32)
                        nextId = idInt + 1
                    }
                }
            }
        }
        print("finished next id: \(nextId)")
    return nextId
    }
}

