# ru_project

Projet info ru.

![exemple](image.png)


![alt text](image-2.png)

## DOC

### Backend

![fonctionnement des tokens](tokens.png)

## Getting Started

First, clone the project:


```bash
git clone https://github.com/PlsJustDoIt/ru_project.git
```

cd into the project directory:

```bash
cd ru_project
```

give permissions to the scripts:

```bash
chmod +x *.sh
```

### Installation of backend

Run the install_backend.sh script:

```bash
./install_backend.sh
```

### cron job

```bash
pwd # copy the path
crontab -e
```
add the following line:

```bash
0 0 * * MON /usr/bin/curl --silent -o {your path to ru_project}/backend/menus.xml 'http://webservices-v2.crous-mobile.fr:8080/feed/bfc/externe/menu.xml' &>/dev/null
```

#### MongoDB

##### Local installation

<!-- ##### Create a database

```bash
mongosh
use admin
```
 -->

follow instructions after step 6 : https://thelinuxforum.com/articles/912-how-to-install-mongodb-on-ubuntu-24-04

create a database:

```bash
mongosh
use admin
db.createUser({
    user:"{your username}", 
    pwd:"password", 
    roles:[{role: "root", db:"admin"}]
    })
```


use the database:

```bash
use ru_project
db.createUser({
    user:"ru_project_user",
    pwd:"ru_project_password",
    roles:[{role: "readWrite", db:"ru_project"}]
    })

exit()
```
#### create a user with admin role:
```bash
# Generate a hashed password
node -e "console.log(require('bcrypt').hashSync('MySecretPassword', 10))"

# Copy the resulting hash and paste it below
mongosh
use ru_project
db.users.insertOne({
    username: "adminUser",
    password: "<PASTE_THE_HASH_HERE>",
    role: "admin"})
exit
```

##### env file

the following instructions are for development mode : 

generate a JWT_ACCESS_SECRET with the following command:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

**copy the key**

**_repeat the operation for the JWT_REFRESH_SECRET._**

add a .env file in the backend directory with the following content:

```bash
MONGO_URI="mongodb://ru_project_user:ru_project_password@127.0.0.1:27017/ru_project?authSource=ru_project"
JWT_ACCESS_SECRET="{your first generated key}"
JWT_REFRESH_SECRET="{your second generated key}"
GINKO_API_KEY="{your ginko api key}"
```


### Install Flutter

run the install_flutter.sh script:

```bash
./install_flutter.sh
```

Now, open vs code and install the following extensions:
- flutter
- dart

and try to create a new flutter project, it will ask you to install the flutter sdk, install it in `~/development/`.

finish the installation of flutter and dart plugins.

#### local installation

in flutter/lib/config.dart, configure the backend url:

```dart
    class config {
    static const String apiUrl = "http://localhost:5000/api";
}
```

## Running the project

### Backend

To run the backend, follow the instructions in the backend directory:
```bash
cd backend
npx tsx watch src/app.ts # watch allows you to restart the server when you save a file
```

### Frontend

It is recommended to launch flutter with vs code, but you can also run it with the following commands:

```bash
flutter pub get
```

```bash
flutter run
```




This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
