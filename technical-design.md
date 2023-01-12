---
header-includes: |
    \setlength{\parskip}{1em plus 2pt minus 1pt}
    \usepackage{titlesec}
        \newcommand{\sectionbreak}{\clearpage}
    \renewcommand{\familydefault}{\sfdefault}
    \usepackage{tikz}
geometry: margin=1.2in
papersize: a4
fontfamily: helvet
linestretch: 1.35
numbersections: true
toc: true
citation-style: apa.csl
bibliography: bibliography.bibtex
citeproc: true
link-citations: true

title: Technical Design
author: Stephan Stanisic (s1128386)
date: 2023-1-13
---

# Introduction {-}

This document describes the technical implementation of the Gaia plant sensor. Here we will go over various aspects of the software architecture design, driven by the problem definition and solution requirements. This document is structured as suggested by Talin and Lawal [@talin2019; @talin2019jan; @lawal2022].

The software architecture is broken down by using the C4 model [@c4model].

# Problem definition

The Gaia plant sensor tries to make the plants wellbeing visible in the app by showing emotions and mood. Currently a minimal viable product has been implemented with basic support for most features. The main problems to be solved in this document are the following:

- How can a esp32 based sensor be setup to log sensor values to an app?
- What is needed to communicate this over wifi?
- How does the sensor recieve wifi network and password information for it to connect to?
- In what way can communication happen while keeping confidentiality, integrity, and availability intact?


# Architecture Choices

## Microservices

There are two main ways of creating software: The monolithic architecture and the microservice architecture. These both have advantages and disadvantages. We have chosen to use a microservice based architecture because this aligns better with our goals.

A monolith is a system where all parts of the software are thightly integrated with each other. Usually this means that the system is a single codebase in a single programming language. This has as the advantage that development becomes easier: everything is deployed and tested all at once. The downside to this is that while horizontally scaling is possible, vertical scaling becomes a lot harder. Also when a single component is modified it can have effect on the system as a whole.

A microservice is a service that only does one thing, where multiple microservices communicate with each other to create a whole. This makes coupling looser, since the public facing API has to be well defined. Also this means that microservices can easily vertically scale since only one microservice has to be updated to support this. When a microservice stops working, or contains a critical bug, this will only have effect on the service that the microservice is providing.

## Limiting CO2 emissions

Green tech is part of the core value of sustainability that we strive to meet. Because of this multiple choices have been made on the basis of CO2 emissions. The following aspects of a technical infrastructure can contribute to CO2 emissions:

- Programming Language used.
- Data center power supply.
- Data center cpu architecture.
- Used algorithms and processes.
- Amount of overhead in actions, especially when running in the cloud.

Because of these factors the following choices have been made about technical infrastructure:

- Cloud infrastructure will be limited if possible. Using the cloud product Firebase will dramatically accellerate development times, but large parts of cloud infrastructure can be simplified and seperated out without taking more time to implement. This will also lower overhead.
- Cloud infrastructure will run in data centers with the highest percentage of green energy available.
- When the choice is available infrastructure will run on arm64 based servers instead of amd64. ARM based infrastructures provide higher power efficency.
- Programming languages will be selected based on cpu time on benchmarks.

This is visible as following in our infrastructure:

- Firebase uses the GCP resource location "europe-west6" by default. This is the location with the highest percentage of green energy available.
- Firebase Functions use the "europe-west1" resource location instead since a higher percentage of green energy is available here.
- Microservices are running on shared hardware using 100% green energy.
- Microservices are written in the Rust programming language since this has the lowest cpu time on benchmarks apart from the C programming language while also offering high level language features.

# Architecture Design

## System Context

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Context.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/store_alt.puml
!include ICONS/devicons2/firebase.puml


sprite $androidios [104x48/16] {
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000230000000000000050000000000000000
000000000000000000000000000000000000000000000000000000000000000000000001D00000000000001D0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000087000000000000A50000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000D127ACDDCA623C00000000000000000
000000000000000000000000000005A800000000000000000000000000000000000000000AFFFFFFFFFFFF800000000000000000
0000000000000000000000000004DFFA0000000000000000000000000000000000000004EFFFFFFFFFFFFFFD3000000000000000
000000000000000000000000006FFFF8000000000000000000000000000000000000007FFFFFFFFFFFFFFFFFF500000000000000
00000000000000000000000005FFFFF300000000000000000000000000000000000007FFFFFFFFFFFFFFFFFFFF50000000000000
0000000000000000000000000EFFFFC00000000000000000000000000000000000003FFFF41EFFFFFFFFD15FFFF2000000000000
0000000000000000000000007FFFFF30000000000000000000000000000000000000CFFFF20DFFFFFFFFC03FFFFA000000000000
000000000000000000000000CFFFF700000000000000000000000000000000000004FFFFFFEFFFFFFFFFFDFFFFFF200000000000
000000000000000000000000FFFF6000000000000000000000000000000000000008FFFFFFFFFFFFFFFFFFFFFFFF600000000000
000000000000000000000000FE82000000000000000000000000000000000000000BFFFFFFFFFFFFFFFFFFFFFFFF900000000000
0000000000000001465300000000168863000000000000000000000000000000000CFFFFFFFFFFFFFFFFFFFFFFFFA00000000000
00000000000003BFFFFFE930016CFFFFFFE800000000000000000000000000000009BBBBBBBBBBBBBBBBBBBBBBBB700000000000
0000000000008FFFFFFFFFFEDFFFFFFFFFFFD2000000000000000000000002BD80023333333333333333333333332008DB200000
00000000000AFFFFFFFFFFFFFFFFFFFFFFFFFE20000000000000000000000EFFF90DFFFFFFFFFFFFFFFFFFFFFFFFB09FFFE00000
00000000008FFFFFFFFFFFFFFFFFFFFFFFFFFF50000000000000000000005FFFFF0DFFFFFFFFFFFFFFFFFFFFFFFFB0FFFFF50000
0000000002FFFFFFFFFFFFFFFFFFFFFFFFFFF400000000000000000000007FFFFF2DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF70000
0000000009FFFFFFFFFFFFFFFFFFFFFFFFFF4000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000000FFFFFFFFFFFFFFFFFFFFFFFFFF90000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000004FFFFFFFFFFFFFFFFFFFFFFFFFF20000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000007FFFFFFFFFFFFFFFFFFFFFFFFFD00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000009FFFFFFFFFFFFFFFFFFFFFFFFFA00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
00000000AFFFFFFFFFFFFFFFFFFFFFFFFF800000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
00000000BFFFFFFFFFFFFFFFFFFFFFFFFFA00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
00000000AFFFFFFFFFFFFFFFFFFFFFFFFFC00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000008FFFFFFFFFFFFFFFFFFFFFFFFFF10000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000006FFFFFFFFFFFFFFFFFFFFFFFFFF70000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000002FFFFFFFFFFFFFFFFFFFFFFFFFFF2000000000000000000000007FFFFF2DFFFFFFFFFFFFFFFFFFFFFFFFB2FFFFF70000
000000000EFFFFFFFFFFFFFFFFFFFFFFFFFFD100000000000000000000005FFFFF0DFFFFFFFFFFFFFFFFFFFFFFFFB0FFFFF40000
000000000AFFFFFFFFFFFFFFFFFFFFFFFFFFFE30000000000000000000000DFFF80DFFFFFFFFFFFFFFFFFFFFFFFFB08FFFC00000
0000000004FFFFFFFFFFFFFFFFFFFFFFFFFFFFF700000000000000000000018B600DFFFFFFFFFFFFFFFFFFFFFFFFB006B8100000
0000000000EFFFFFFFFFFFFFFFFFFFFFFFFFFFF5000000000000000000000000000DFFFFFFFFFFFFFFFFFFFFFFFFB00000000000
00000000007FFFFFFFFFFFFFFFFFFFFFFFFFFFE0000000000000000000000000000CFFFFFFFFFFFFFFFFFFFFFFFFA00000000000
00000000001FFFFFFFFFFFFFFFFFFFFFFFFFFF700000000000000000000000000007FFFFFFFFFFFFFFFFFFFFFFFF500000000000
000000000007FFFFFFFFFFFFFFFFFFFFFFFFFD000000000000000000000000000000AFFFFFFFFFFFFFFFFFFFFFF8000000000000
000000000000DFFFFFFFFFFFFFFFFFFFFFFFF40000000000000000000000000000000255BEEEEE6556EEEEEB5410000000000000
0000000000003FFFFFFFFFFFFFFFFFFFFFFFA000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
00000000000006FFFFFFFFFFFFFFFFFFFFFD0000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
000000000000008FFFFFFFFFFFFFFFFFFFE20000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
0000000000000008FFFFFD84236BFFFFFD200000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
000000000000000039A840000000169960000000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000008FFFFF0000FFFFF80000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000004FFFFC0000CFFFF40000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000009FFE300002EFFA00000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000351000000153000000000000000000
}

scale 2

Person(person, "Plant Parent", "The target audience")

System(app, "Gaia", "The Gaia mobile phone app", $sprite="phone_android")
System_Ext(appstore, "Play- and AppStore", "Stores hosting our app", $sprite="store_alt")
System_Ext(androidios, "iOS and Android", "Operating system APIs used", $sprite="androidios")
System_Ext(firebase, "Firebase", "Cloud Services", $sprite="firebase")

System(sensor, "Sensor", "The physical sensor in the plant", $sprite="seedling")

Rel_R(person, app, "Installs and uses", "App- and PlayStore")
Rel_R(app, sensor, "Uses data from", "Bluetooth")
Rel_D(app, appstore, "Is available on")
Rel_D(app, androidios, "Uses")
Rel_D(app, firebase, "Uses")
@enduml
```

## Containers

### Gaia

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Container.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/store_alt.puml
!include ICONS/font-awesome-5/lock.puml
!include ICONS/font-awesome-5/clock.puml
!include ICONS/devicons2/firebase.puml

sprite $androidios [104x48/16] {
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000230000000000000050000000000000000
000000000000000000000000000000000000000000000000000000000000000000000001D00000000000001D0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000087000000000000A50000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000D127ACDDCA623C00000000000000000
000000000000000000000000000005A800000000000000000000000000000000000000000AFFFFFFFFFFFF800000000000000000
0000000000000000000000000004DFFA0000000000000000000000000000000000000004EFFFFFFFFFFFFFFD3000000000000000
000000000000000000000000006FFFF8000000000000000000000000000000000000007FFFFFFFFFFFFFFFFFF500000000000000
00000000000000000000000005FFFFF300000000000000000000000000000000000007FFFFFFFFFFFFFFFFFFFF50000000000000
0000000000000000000000000EFFFFC00000000000000000000000000000000000003FFFF41EFFFFFFFFD15FFFF2000000000000
0000000000000000000000007FFFFF30000000000000000000000000000000000000CFFFF20DFFFFFFFFC03FFFFA000000000000
000000000000000000000000CFFFF700000000000000000000000000000000000004FFFFFFEFFFFFFFFFFDFFFFFF200000000000
000000000000000000000000FFFF6000000000000000000000000000000000000008FFFFFFFFFFFFFFFFFFFFFFFF600000000000
000000000000000000000000FE82000000000000000000000000000000000000000BFFFFFFFFFFFFFFFFFFFFFFFF900000000000
0000000000000001465300000000168863000000000000000000000000000000000CFFFFFFFFFFFFFFFFFFFFFFFFA00000000000
00000000000003BFFFFFE930016CFFFFFFE800000000000000000000000000000009BBBBBBBBBBBBBBBBBBBBBBBB700000000000
0000000000008FFFFFFFFFFEDFFFFFFFFFFFD2000000000000000000000002BD80023333333333333333333333332008DB200000
00000000000AFFFFFFFFFFFFFFFFFFFFFFFFFE20000000000000000000000EFFF90DFFFFFFFFFFFFFFFFFFFFFFFFB09FFFE00000
00000000008FFFFFFFFFFFFFFFFFFFFFFFFFFF50000000000000000000005FFFFF0DFFFFFFFFFFFFFFFFFFFFFFFFB0FFFFF50000
0000000002FFFFFFFFFFFFFFFFFFFFFFFFFFF400000000000000000000007FFFFF2DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF70000
0000000009FFFFFFFFFFFFFFFFFFFFFFFFFF4000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000000FFFFFFFFFFFFFFFFFFFFFFFFFF90000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000004FFFFFFFFFFFFFFFFFFFFFFFFFF20000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000007FFFFFFFFFFFFFFFFFFFFFFFFFD00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000009FFFFFFFFFFFFFFFFFFFFFFFFFA00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
00000000AFFFFFFFFFFFFFFFFFFFFFFFFF800000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
00000000BFFFFFFFFFFFFFFFFFFFFFFFFFA00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
00000000AFFFFFFFFFFFFFFFFFFFFFFFFFC00000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000008FFFFFFFFFFFFFFFFFFFFFFFFFF10000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000006FFFFFFFFFFFFFFFFFFFFFFFFFF70000000000000000000000008FFFFF3DFFFFFFFFFFFFFFFFFFFFFFFFB3FFFFF80000
000000002FFFFFFFFFFFFFFFFFFFFFFFFFFF2000000000000000000000007FFFFF2DFFFFFFFFFFFFFFFFFFFFFFFFB2FFFFF70000
000000000EFFFFFFFFFFFFFFFFFFFFFFFFFFD100000000000000000000005FFFFF0DFFFFFFFFFFFFFFFFFFFFFFFFB0FFFFF40000
000000000AFFFFFFFFFFFFFFFFFFFFFFFFFFFE30000000000000000000000DFFF80DFFFFFFFFFFFFFFFFFFFFFFFFB08FFFC00000
0000000004FFFFFFFFFFFFFFFFFFFFFFFFFFFFF700000000000000000000018B600DFFFFFFFFFFFFFFFFFFFFFFFFB006B8100000
0000000000EFFFFFFFFFFFFFFFFFFFFFFFFFFFF5000000000000000000000000000DFFFFFFFFFFFFFFFFFFFFFFFFB00000000000
00000000007FFFFFFFFFFFFFFFFFFFFFFFFFFFE0000000000000000000000000000CFFFFFFFFFFFFFFFFFFFFFFFFA00000000000
00000000001FFFFFFFFFFFFFFFFFFFFFFFFFFF700000000000000000000000000007FFFFFFFFFFFFFFFFFFFFFFFF500000000000
000000000007FFFFFFFFFFFFFFFFFFFFFFFFFD000000000000000000000000000000AFFFFFFFFFFFFFFFFFFFFFF8000000000000
000000000000DFFFFFFFFFFFFFFFFFFFFFFFF40000000000000000000000000000000255BEEEEE6556EEEEEB5410000000000000
0000000000003FFFFFFFFFFFFFFFFFFFFFFFA000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
00000000000006FFFFFFFFFFFFFFFFFFFFFD0000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
000000000000008FFFFFFFFFFFFFFFFFFFE20000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
0000000000000008FFFFFD84236BFFFFFD200000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
000000000000000039A840000000169960000000000000000000000000000000000000009FFFFF1001FFFFFA0000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000008FFFFF0000FFFFF80000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000004FFFFC0000CFFFF40000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000009FFE300002EFFA00000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000351000000153000000000000000000
}

scale 2

Person(person, "Plant Parent", "The target audience")

System_Boundary(app, "Gaia") {
  Container(flutter, "App", "Flutter", "Main interface with the sensor", $sprite="phone_android")
  Container(temporal, "Temporal", "Rust Container Microservice", "Collects high-volume time series data", $sprite="clock")
  Container(auth, "Auth", "Rust Container Microservice", "Bridge to Firebase Authentication and ensures integrity for data access", $sprite="lock")
}
System_Ext(appstore, "Play- and AppStore", "Stores hosting our app", $sprite="store_alt")
System_Ext(androidios, "iOS and Android", "Operating system APIs used", $sprite="androidios")
System_Boundary(firebase, "Google Firebase") {
  Container_Ext(functions, "Functions", "NodeJS", "Collects current sensor readings and denormalizes them to Firestore", $sprite="firebase")
  ContainerDb_Ext(firestore, "Firestore", "Document Store", "Stores avatar and calibration data for app", $sprite="firebase")
  Container_Ext(authentication, "Authentication", "Cloud Service", "SMS Based Authentication", $sprite="firebase")
}

System(sensor, "Sensor", "The physical sensor in the plant", $sprite="seedling")

Rel(person, flutter, "Installs and uses", "App- and PlayStore")
Rel(flutter, sensor, "Uses data from", "Bluetooth")
Rel(flutter, appstore, "Is available on")
Rel(flutter, androidios, "Uses")

Rel(sensor, temporal, "Logs raw sensor readings hourly", "HTTPS, Bearer token")
Rel(temporal, auth, "Checks passed bearer tokens", "HTTPS")
Rel(auth, authentication, "Verifies JWT tokens", "Certificates retrieved over HTTPS")
Rel(flutter, firestore, "Read/writes data", "Library Bindings")
Rel(functions, temporal, "Requests latest data hourly", "HTTPS, API KEY")
Rel(flutter, auth, "Creates new bearer token for sensor", "HTTPS, JWT")
Rel(functions, firestore, "Updates data in", "Library Bindings")
@enduml

```

### Sensor

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Container.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/material/sd_storage.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/file.puml
!include ICONS/font-awesome-5/lock.puml
!include ICONS/font-awesome-5/clock.puml
!include ICONS/devicons2/c.puml

scale 2

Container(flutter, "App", "Flutter", "Main interface with the sensor", $sprite="phone_android")
Container(temporal, "Temporal", "Rust Container Microservice", "Collects high-volume time series data", $sprite="clock")
  
System_Boundary(sensor, "Sensor") {
  Container(blufi, "Blufi", "Library", "Espressif library for configuring wifi over bluetooth with encrypted bluetooth communication", $sprite="c")
  Container(customdata, "Custom Data Callback", "function", "Function that gets called when the custom data callback is called from blufi, carrying both the sid and token.", $sprite="file")
  Container(deepsleep, "Deep Sleep Timer", "function", "Hourly timer that triggers when sensor is configured to measure and log data", $sprite="clock")
  ContainerDb(nvs, "Non Volitile Storage", "Library", "Bindings for EEPROM on the ESP32, paged and 0-terminated.", $sprite="sd_storage")
}

Rel(flutter, blufi, "Configures sid and token", "Bluetooth")
Rel(flutter, blufi, "Configures wifi and password", "Bluetooth")
Rel(deepsleep, temporal, "Logs raw sensor readings hourly", "HTTPS, Bearer token")
Rel(customdata, nvs, "Store sid and token in nvs", "Library Bindings")
Rel(deepsleep, nvs, "Read sid and token from nvs", "Library Bindings")
Rel(blufi, customdata, "Configures callback", "Library Bindings")
@enduml

```

## Components

### App

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Component.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/store_alt.puml
!include ICONS/font-awesome-5/lock.puml
!include ICONS/font-awesome-5/clock.puml
!include ICONS/font-awesome-5/file.puml
!include ICONS/font-awesome-5/cogs.puml
!include ICONS/font-awesome-5/sync.puml
!include ICONS/font-awesome-5/table.puml
!include ICONS/devicons2/firebase.puml

scale 2

Container_Boundary(flutter, "App") {
  Component(blufiprovider, "BlufiProvider", "Change Notifier, Singleton", "Class that allows interfaces to easily change dependencies when bluetooth connection state changes.", $sprite="sync")
  Component(userdal, "User DAL", "Data Transfer Object", "Class that represents users in firestore, using generated ORM code", $sprite="table")
  Component(plantdal, "Plant DAL", "Data Transfer Object", "Class that represents plants in firestore, using generated ORM code", $sprite="table")

  Component(authcontroller, "Auth Controller", "Singleton", "Singleton class that manages tokens by querying the auth microservice", $sprite="cogs")
  Component(plantcontroller, "Plant Controller", "Singleton", "Class that manages current user's plant configuration", $sprite="cogs")
  Component(usercontroller, "User Controller", "Singleton", "Class that manages current logged in user", $sprite="cogs")

  Component(indexpage, "App Index", "Widget", "Initial page that directs control flow on app open", $sprite="file")
  Component(connectsensor, "Connect Sensor", "Widget", "Page that allows to setup a new sensor connection", $sprite="file")
  Component(calibratesensor, "Calibrate Sensor", "Widget", "Page that allows the user to calibrate the sensor", $sprite="file")
  Component(homepage, "Home", "Widget", "Home page with plant avatar that also shows the current state of the plant", $sprite="file")
}

Container(auth, "Auth", "Rust Container Microservice", "Bridge to Firebase Authentication and ensures integrity for data access", $sprite="lock")
System_Boundary(firebase, "Google Firebase") {
  ContainerDb_Ext(firestore, "Firestore", "Document Store", "Stores avatar and calibration data for app", $sprite="firebase")
  Container_Ext(authentication, "Authentication", "Cloud Service", "SMS Based Authentication", $sprite="firebase")
}

System(sensor, "Sensor", "The physical sensor in the plant", $sprite="seedling")

Rel(blufiprovider, sensor, "Uses data from", "Bluetooth")

Rel(userdal, firestore, "Read/writes data", "Library Bindings")
Rel(plantdal, firestore, "Read/writes data", "Library Bindings")
Rel(usercontroller, authentication, "Logs in by SMS", "Library Bindings")
Rel(usercontroller, userdal, "Retrieves account data", "Method calls")
Rel(authcontroller, auth, "Creates new bearer token for sensor", "HTTPS, JWT")
Rel(plantcontroller, plantdal, "Retrieves plant and avatar data", "Method calls")

Rel(indexpage, authcontroller, "Checks if user is logged in", "Method calls")
Rel(indexpage, connectsensor, "Shows connect page if no sensor is connected", "Widget constructor")
Rel(indexpage, calibratesensor, "Shows calibration page is sensor is connected but without calibration data", "Widget constructor")
Rel(indexpage, homepage, "Shows home page if sensor is set up correctly", "Widget constructor")

Rel(connectsensor, blufiprovider, "Setup wifi connection over bluetooth", "Method calls")
Rel(connectsensor, usercontroller, "Add sensor to user account", "Method calls")
Rel(calibratesensor, plantcontroller, "Setup plant calibration data", "Method calls")
Rel(homepage, plantcontroller, "Get plant status", "Method calls")
Rel_R(plantcontroller, usercontroller, "Get connected plants", "Method calls")
@enduml

```

### Temporal

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Component.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/store_alt.puml
!include ICONS/font-awesome-5/lock.puml
!include ICONS/font-awesome-5/file.puml
!include ICONS/devicons2/firebase.puml
!include ICONS/devicons2/postgresql.puml

scale 2

Container_Boundary(temporal, "Temporal") {
  Component(log, "Log Endpoint", "function", "Endpoint that accepts log data in json format and stores it in the database", $sprite="file")
  Component(alldata, "Request Latest Data Endpoint", "function", "Endpoint that queries the database for all latest sensor readings", $sprite="file")

  Component(gaiaauth, "Gaia Auth Module", "Managed Stateful Struct", "", $sprite="lock")
  Component(apikey, "API Key Auth Module", "Managed Stateful Struct", "", $sprite="lock")

  ComponentDb(db, "Temporal Database", "PostgreSQL", "PostgreSQL database that stores all time series data", $sprite="postgresql")
}
Container(auth, "Auth", "Rust Container Microservice", "Bridge to Firebase Authentication and ensures integrity for data access", $sprite="lock")
Container_Ext(functions, "Functions", "NodeJS", "Collects current sensor readings and denormalizes them to Firestore", $sprite="firebase")


System(sensor, "Sensor", "The physical sensor in the plant", $sprite="seedling")


Rel(sensor, log, "Logs raw sensor readings hourly", "HTTPS, Bearer token")
Rel(gaiaauth, auth, "Checks passed bearer tokens", "HTTPS")
Rel(functions, alldata, "Requests latest data hourly", "HTTPS, API KEY")
Rel(alldata, apikey, "Validate API Key", "Method Call")
Rel(log, gaiaauth, "Validate bearer token", "Method Call")
Rel_L(log, db, "Store data", "Library")
Rel_R(alldata, db, "Query latest data", "Library")
@enduml

```

### Auth

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Component.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/file.puml
!include ICONS/font-awesome-5/lock.puml
!include ICONS/font-awesome-5/clock.puml
!include ICONS/devicons2/firebase.puml
!include ICONS/devicons2/postgresql.puml

scale 2

Container(flutter, "App", "Flutter", "Main interface with the sensor", $sprite="phone_android")
Container(temporal, "Temporal", "Rust Container Microservice", "Collects high-volume time series data", $sprite="clock")
Container_Boundary(auth, "Auth"){
  Component(verify, "Verify Endpoint", "method", "Endpoint responsible for verifying bearer token and jwt tokens.", $sprite="file")
  Component(create, "Create Sensor Endpoint", "method", "Endpoint responsible for creating new sid and token pairs", $sprite="file")
  Component(bearertokenauth, "Bearer Token Auth Module", "Managed State Struct", "Auth module responsible for checking sensor sid and token pairs against stored versions.", $sprite="lock")
  Component(jwtokenauth, "JWT Auth Module", "Managed State Struct", "Module responsible for verifying signed JSON Web Tokens against fetched certificates from Google Cloud", $sprite="lock")
  ComponentDb(db, "Auth Database", "PostgreSQL", "PostgreSQL database responsible for storing sid and hashed token pairs", $sprite="postgresql")
}

Container_Ext(authentication, "Authentication", "Cloud Service", "SMS Based Authentication", $sprite="firebase")

Rel(temporal, verify, "Checks passed bearer tokens", "HTTPS")
Rel(jwtokenauth, authentication, "Verifies JWT tokens", "Certificates retrieved over HTTPS")
Rel(flutter, create, "Creates new bearer token for sensor", "HTTPS, JWT")
Rel(verify, bearertokenauth, "Check bearer token", "Library")
Rel(verify, jwtokenauth, "Check JWT against cached certificates", "Library")
Rel_D(bearertokenauth, db, "Check against DB", "Library")
Rel_L(create, db, "Create sensor pair in DB", "Library")
@enduml

```


### Firebase Functions

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/d193a84febce699caf236e3115dbed5ac8418397/C4_Component.puml
!define ICONS https://raw.githubusercontent.com/tupadr3/plantuml-icon-font-sprites/fa3f885dbd45c9cd0cdf6c0e5e4fb51ec8b76582
!include ICONS/material/phone_android.puml
!include ICONS/font-awesome-5/seedling.puml
!include ICONS/font-awesome-5/store_alt.puml
!include ICONS/font-awesome-5/lock.puml
!include ICONS/font-awesome-5/clock.puml
!include ICONS/devicons2/firebase.puml
!include ICONS/devicons2/nodejs.puml


scale 2

Container(temporal, "Temporal", "Rust Container Microservice", "Collects high-volume time series data", $sprite="clock")
Container_Ext(cron, "CRON", "Cronjob", "Runs hourly", $sprite="clock")
System_Boundary(firebase, "Google Firebase") {
  Container_Boundary(functions, "Functions"){
    Component(update, "Update Firestore", "Cloud Function", "Collects current sensor readings and denormalizes them to Firestore", $sprite="nodejs")
  }
  ContainerDb_Ext(firestore, "Firestore", "Document Store", "Stores avatar and calibration data for app", $sprite="firebase")
}

Rel(update, temporal, "Requests latest data hourly", "HTTPS, API KEY")
Rel(update, firestore, "Updates data in", "Library Bindings")
Rel_R(cron, update, "Calls Hourly", "HTTPS")
@enduml


```


# Operational Readiness Considerations

The entire infrastructure is dedigned to be easily scalable but also easy to deploy on smaller scale infrastructure. All source code repositories contain docker files compatiable with the nix development environment and even include sample docker-compose configuration. Note that passwords in docker-compose need to be changed before deploying.

## Security Considerations

On the 23rd of December 2022 a penetration test was executed by a team of students from the semester Applied IT Security. Their summary contained that the app didn't contain critical security leaks.

One possible attack target is reading data from other sensors. This is possible by guessing a sensor's sid, and setting this in firestore as a users own sensor. Then the data of this sensor can be read. This is not a critical security issue since it only contains raw readings of the sensor, created avatar and other non-critical information. Also since the sensor id is created using a secure random generator it is hard if not impossible to predict newly generated sensor ids. The solution for this is to create a cloud function to handle sensor connection/creation, and remove the rights of setting ones own sensor sid.



# References {-}
&nbsp;
