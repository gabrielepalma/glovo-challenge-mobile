# Glovo Interview Application

The application is structured in a Network layer, a Data layer and a UI layer.
The Network layer is simply made up of DTOs, a NetworkManager and the API implementations and it uses Promises to simplify callback management. 

The Data layer is built as an offline-first data synchronization layer, of design similar to my own pet project [Sublimate](https://github.com/gabrielepalma/sublimate) but it has been simplified, since this application only requires synchronization downstream and not upstream. The data is then cached in a Realm database. Unfortunately, due to how the Glovo API was designed, it does not support full offline synchronization (some data in the city detail API is not available in the city listing API) and thus we require some network calls being sent beyond the core synchronization process. 

Parts of the Data layer and the UI layer are using RxSwift to maintain a reactive behavior. Since it was part of the requirements the UI layer also uses SnapKit to set up AutoLayout constraints. In order to decompose responsibilities and maintain the MapViewController of an acceptable size, two view models are also provided: one to manage CoreLocation logic and another to convert Polyline data to a more immediately usable format. The list of cities, with their countries, is assembled directly from Realm data and is presented in a sectioned UITableViewController.

Since testing was not mentioned at all in the requirement document, Unit Tests were deemed out of scope for this exercise and are not provided. Despise that, the application is still designed with an eye to Testability: it makes use of Swinject containers to adopt both Dependency Injection and Dependency Inversion such that almost all dependencies are abstract and are injected during class initialization and only resolved from the container when needed. This makes it easy to isolate class dependencies and replace them, for example when it is necessary to inject mock implementations during testing.

Framework dependencies have been managed using CocoaPods and for your convenience have been fully committed to the repository, thus no dependency installation should be required.
