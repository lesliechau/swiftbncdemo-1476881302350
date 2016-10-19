/**
* Copyright IBM Corporation 2016
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
**/

import Kitura
import SwiftyJSON
import LoggerAPI
import CloudFoundryEnv

public class Controller {

  let router: Router
  let appEnv: AppEnv

  var port: Int {
    get { return appEnv.port }
  }

  var url: String {
    get { return appEnv.url }
  }

  init() throws {
    appEnv = try CloudFoundryEnv.getAppEnv()

    // All web apps need a Router instance to define routes
    router = Router()

    // Serve static content from "public"
    router.all("/", middleware: StaticFileServer())

    // Basic GET request
    router.get("/api/v1/emplsalaries", handler: getEmployeeSalaries)

   
  }

  public func getEmployeeSalaries(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("GET - /api/v1/emplsalaries route handler...")
    response.headers["Content-Type"] = "application/json; charset=utf-8"
    
    let host = "ibmswift.cloudant.com"
	let username = "ibmswift"
	let password = "s3rv3rs1desw1ft"
	let databaseName = "empldb"
	
	typealias StringValuePair = [String : Any]
	protocol StringValuePairConvertible {
	    var stringValuePairs: StringValuePair {get}
	}
	
	extension Array where Element : StringValuePairConvertible {
	    var stringValuePairs: [StringValuePair] {
	        return self.map { $0.stringValuePairs }
	    }
	}
	
	let connectionProperties = ConnectionProperties(
	    host: host,
	    port: 80,
	    secured: false,
	    username: username,
	    password: password
	)
	
	struct Employee {
	    let empno: String
	    let firstName: String
	    let lastName: String
	    let salary: Int
	
	    init(json: JSON) {
	        empno = json["empno"].stringValue.capitalized
	        firstName = json["firstnme"].stringValue.capitalized
	        lastName = json["lastname"].stringValue.capitalized
	        salary = json["salary"].intValue
	    }
	}
	
	extension Employee: StringValuePairConvertible {
	    var stringValuePairs: [String: Any] {
	        return ["empno": self.empno,
	                "firstName": self.firstName,
	                "lastName": self.lastName,
	                "salary": self.salary]
	    }
	}
	
	let cloudantClient = CouchDBClient(connectionProperties: connectionProperties)
	let database = cloudantClient.database(databaseName)
    
    database.retrieveAll(includeDocuments: true) { json, error in
    
        guard let json = json else {
            response.status(.badRequest)
            return
        }

        let employees = json["rows"].map { _, row in
            return Employee.init(json: row["doc"])
        }

        response.status(.OK).send(json: JSON(employees.stringValuePairs))
        next()
    }
    
    
  }

 

}
