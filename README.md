# ru_project

Projet info ru.

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
```

```bash
db.createUser({
    user:"ru_project_user",
    pwd:"ru_project_password",
    roles:[{role: "root", db:"admin"}]
    })
```
use the database:

```bash
use ru_project
exit()
```

##### env file
add a .env file in the backend directory with the following content:

```bash
MONGO_URI="mongodb://ru_project_user:ru_project_password@127.0.0.1:27017/ru_project?authSource=ru_project"
JWT_SECRET="9b9f4cf8d331fbe0110b7a42b196512790062d7dc29369fcdfa84a5e8d6301c8"
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

##### env file
add a .env file in the flutter directory with the following content:

```bash
API_URL="http://localhost:5000/api"
```

## Running the project

### Backend

To run the backend, follow the instructions in the backend directory:
```bash
cd backend
node .
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
