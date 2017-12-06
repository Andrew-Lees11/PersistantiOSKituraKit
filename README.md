<h1 align="center"> Kitura 2 Sample App - ToDo List </h1>

<p align="center">
<img src="https://www.ibm.com/cloud-computing/bluemix/sites/default/files/assets/page/catalog-swift.svg" width="120" alt="Kitura Bird">
</p>

<p align="center">
<a href="https://travis-ci.org/IBM-Swift/iOSSampleKituraKit">
    <img src="https://travis-ci.org/IBM-Swift/iOSSampleKituraKit.svg?branch=master" alt="Travis CI">
</a>
<a href= "http://swift-at-ibm-slack.mybluemix.net/"> 
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg"  alt="Slack"> 
</a>
</p>


[Kituta is a lightweight and simple web framework](http://kitura.io) that makes it easy to set up complex web routes for web services and applications. 

PersistentiOSKituraKit provides an example of the todo list application [iOSSampleKituraKit](https://github.com/IBM-Swift/iOSSampleKituraKit) which has been connected to a mySQL database. This means that, if the server is restarted, the data will persist inside the database. For more details view the README in [ToDoServer](https://github.com/Andrew-Lees11/PersistentiOSKituraKit/tree/master/ToDoServer).

If you would like to import KituraKit into your own iOS project please see [How to Import KituraKit to an iOS Project](http://github.com/IBM-Swift/iOSSampleKituraKit/blob/master/KituraiOS/KituraKit/README.md).

### Quick Start*
1. Install mySQL

`brew install mysql`

2. Start the mySQL server

`mysql.server start`

3. setup ToDoDatabase

```
mysql -uroot -e "CREATE USER 'swift'@'localhost' IDENTIFIED BY 'kuery';"
mysql -uroot -e "CREATE DATABASE IF NOT EXISTS ToDoDatabase;"
mysql -uroot -e "GRANT ALL ON ToDoDatabase.* TO 'swift'@'localhost';"
```
4. create toDoTable in database

```
mysql -uroot;
use ToDoDatabase;
CREATE TABLE toDoTable (
    toDo_id INT NOT NULL,
    toDo_title VARCHAR(50),
    toDo_user VARCHAR(50),
    toDo_order INT,
    toDo_completed BOOLEAN,
    toDo_url VARCHAR(50),
    PRIMARY KEY ( toDo_id )
);
```

5. Exit mysql using `\q`

6. Install [Xcode 9](https://itunes.apple.com/gb/app/xcode/id497799835) or later.

7. Clone this repository:

    `git clone https://github.com/Andrew-Lees11/PersistentiOSKituraKit.git
`

8. Navigate into the [ToDoServer folder](https://github.com/Andrew-Lees11/PersistentiOSKituraKit/tree/master/ToDoServer) using:

    `cd PersistentiOSKituraKit/ToDoServer/`

9. Run the following commands to compile the code:

    `swift build -Xlinker -L/usr/local/lib`

10. Start the server with:

    `.build/x86_64-apple-macosx10.10/debug/ToDoServer`

**Note:** This command will start the server and it will listen for new connections forever, so the terminal window will be unable to take new commands while the server is running. For more info on the Server component, [click here](https://github.com/IBM-Swift/iOSSampleKituraBuddy/blob/master/ToDoServer/README.md).

11. Open new Terminal window to continue with the Quick Start.

12. Navigate into the [KituraiOS folder](https://github.com/Andrew-Lees11/PersistentiOSKituraKit/tree/master/KituraiOS) using:

   `cd /PersistentiOSKituraKit/KituraiOS`

13. Open the iOS Sample Kitura Buddy.xcodeproj file with:

    `open iOSKituraKitSample.xcodeproj`

A new Xcode window will open. For more info on the iOS app, [click here](https://github.com/IBM-Swift/iOSSampleKituraKit/blob/master/KituraiOS/README.md).

14. Ensure that the Scheme in Xcode is set to the iOS Application. The Scheme selection is located along the top of the Xcode window next to the Run and Stop buttons. If you don't see a Kitura icon (white and blue) in the box next to the Stop button, click the icon that's there and select the App from the drop down menu.

15. Make sure an iPhone X is selected in the drop down menu next to the Scheme, not "Generic iOS Device". The iPhone Simulators all have blue icons next to their names. iPad is not supported at this time.

16. Press the Run button or ⌘+R. The project will build and the simulator will launch the application. Navigate your web browser to the address http://localhost:8080 to see an empty array. This is where ToDos made in the app are stored. As you add or delete elements in the app, this array will change.

*The Kitura component can be run on Linux or macOS. Xcode is not required for running the Kitura server component (Xcode is only required for the iOS component).

17. You now have a todolist application, running on a simulated iphone. You can add, delete and edit todo items in the list op the app and then view your changes on the server at [localhost:8080](http://localhost:8080/). Since there is a database connected, you can restart both the application and the server but any todolist items you have created will persist!
