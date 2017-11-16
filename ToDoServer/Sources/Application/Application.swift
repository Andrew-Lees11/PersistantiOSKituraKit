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
//        router.put("/", handler: updatePutHandler)
        
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
                        for row in resultSet.rows {
                            guard let currentToDo = self.rowToDo(row: row) else{
                                completion(nil, .internalServerError)
                                return
                            }
                            tempToDoStore.append(currentToDo)
                        }
                    }
                    else if let queryError = queryResult.asError {
                        // Something went wrong.
                        print("select query error: \(queryError)")
                        completion(nil, .internalServerError)
                        return
                    }
                }
            }
        }
        completion(tempToDoStore, nil)
    }
    
    func getOneHandler(id: Int, completion: @escaping (ToDo?, RequestError?) -> Void ) -> Void {
        connection.connect() { error in
            if error != nil {
                print("connection error: \(String(describing: error))")
                return
            }
            else {
                let selectQuery = Select(from :todotable).where(todotable.toDo_id == id)
                connection.execute(query: selectQuery) { queryResult in
                    var foundToDo: ToDo? = nil
                    if let resultSet = queryResult.asResultSet {
                        for row in resultSet.rows {
                            foundToDo = self.rowToDo(row: row)
                        }
                        if foundToDo == nil {
                            completion(nil, .notFound)
                            return
                        }
                        completion(foundToDo,nil)
                    }
                    else if let queryError = queryResult.asError {
                        // Something went wrong.
                        print("select query error: \(queryError)")
                        completion(nil, .internalServerError)
                        return
                    }
                }
            }
        }
    }
    
    func deleteAllHandler(completion: @escaping (RequestError?) -> Void ) -> Void {
        connection.connect() { error in
            if error != nil {
                print("connection error: \(String(describing: error))")
                return
            }
            else {
                let deleteQuery = Delete(from :todotable)
                connection.execute(query: deleteQuery) { queryResult in
                    if queryResult.asError != nil {
                        completion(.internalServerError)
                        return
                    }
                }

            }
        }
        completion(nil)
    }
    
    func deleteOneHandler(id: Int, completion: @escaping (RequestError?) -> Void ) -> Void {
        connection.connect() { error in
            if error != nil {
                print("connection error: \(String(describing: error))")
                return
            }
            else {
                let deleteQuery = Delete(from :todotable).where(todotable.toDo_id == id)
                connection.execute(query: deleteQuery) { queryResult in
                    if queryResult.asError != nil {
                        completion(.internalServerError)
                        return
                    }
                }
                
            }
        }
        completion(nil)
    }
    
    func updateHandler(id: Int, new: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void ) -> Void {
        var current: ToDo?
        connection.connect() { error in
            if error != nil {
                print("connection error: \(String(describing: error))")
                return
            }
            else {
                let selectQuery = Select(from :todotable).where(todotable.toDo_id == id)
                connection.execute(query: selectQuery) { queryResult in
                    if let resultSet = queryResult.asResultSet {
                        for row in resultSet.rows {
                            current = self.rowToDo(row: row)
                            }
                        }
                    else if let queryError = queryResult.asError {
                        // Something went wrong.
                        print("select query error: \(queryError)")
                        completion(nil, .internalServerError)
                        return
                    }
                guard var current = current else {return}
                current.title = new.title ?? current.title
                guard let title = current.title else {return}
                current.user = new.user ?? current.user
                guard let user = current.user else {return}
                current.order = new.order ?? current.order
                guard let order = current.order else {return}
                current.completed = new.completed ?? current.completed
                guard let completed = current.completed else {return}
                let updateQuery = Update(self.todotable, set: [(self.todotable.toDo_title, title),(self.todotable.toDo_user, user),(self.todotable.toDo_order, order),(self.todotable.toDo_completed, completed)]).where(self.todotable.toDo_id == id)
                    self.connection.execute(query: updateQuery) { queryResult in
                    if queryResult.asError != nil {
                        completion(nil, .internalServerError)
                        return
                    }
                    completion(current, nil)
                }
                }
            }
        }
    }

    func updatePutHandler(id: Int, new: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void ) -> Void {
        var current: ToDo?
        connection.connect() { error in
            if error != nil {
                print("connection error: \(String(describing: error))")
                return
            }
            else {
                let selectQuery = Select(from :todotable).where(todotable.toDo_id == id)
                connection.execute(query: selectQuery) { queryResult in
                    if let resultSet = queryResult.asResultSet {
                        for row in resultSet.rows {
                            current = self.rowToDo(row: row)
                        }
                    }
                    else if let queryError = queryResult.asError {
                        // Something went wrong.
                        print("select query error: \(queryError)")
                        completion(nil, .internalServerError)
                        return
                    }
                    guard var current = current else {return}
                    current.title = new.title
                    guard let title = current.title else {return}
                    current.user = new.user
                    guard let user = current.user else {return}
                    current.order = new.order
                    guard let order = current.order else {return}
                    current.completed = new.completed
                    guard let completed = current.completed else {return}
                    let updateQuery = Update(self.todotable, set: [(self.todotable.toDo_title, title),(self.todotable.toDo_user, user),(self.todotable.toDo_order, order),(self.todotable.toDo_completed, completed)]).where(self.todotable.toDo_id == id)
                    self.connection.execute(query: updateQuery) { queryResult in
                        if queryResult.asError != nil {
                            completion(nil, .internalServerError)
                            return
                        }
                        completion(current, nil)
                    }
                }
            }
        }
    }

    
    private func getNextId() -> Int {
        var nextId = 0
        connection.connect() { error in
            if error != nil {
                print("get id connection error")
                return
            }
            let maxIdQuery = Select(max(todotable.toDo_id) ,from: todotable)
            connection.execute(query: maxIdQuery) { queryResult in
                if let resultSet = queryResult.asResultSet {
                    for row in resultSet.rows {
                        guard let id = row[0] else{return}
                        guard let id32 = id as? Int32 else{return}
                        let idInt = Int(id32)
                        nextId = idInt + 1
                    }
                }
            }
        }
    return nextId
    }
    
    private func rowToDo(row: Array<Any?>) -> ToDo? {
        guard let id = row[0], let id32 = id as? Int32 else{return nil}
        let idInt = Int(id32)
        guard let title = row[1], let titleString = title as? String else {return nil}
        guard let user = row[2], let userString = user as? String else {return nil}
        guard let order = row[3], let orderInt32 = order as? Int32 else {return nil}
        let orderInt = Int(orderInt32)
        guard let completed = row[4], let completedBool = completed as? Bool else {return nil}
        guard let url = row[5], let urlString = url as? String else {return nil}
        return ToDo(id: idInt, title: titleString, user: userString, order: orderInt, completed: completedBool, url: urlString)
    }
}

