# JobberSoft Orders & Shipments

An offline-first Flutter application for fuel dispatch operations. Dispatchers can create fuel orders for stores, allocate requested gallons to underground tanks, and plan shipments by assigning trucks, drivers, terminals and truck compartments.

The application stores operational data locally in SQLite so the core workflows can operate without an internet connection.

## Demo Video

[Watch the application walkthrough](https://github.com/sunildholpuria123/jobbersoft_orders/blob/master/Recording%202026-11-18%20145803.mp4)

## 1. Technology Stack

| Technology | Purpose |
|---|---|
| Flutter 3.41.9 | Mobile application framework |
| Dart 3.11.5 | Programming language |
| flutter_bloc | State management |
| reactive_forms | Form handling and validation |
| sqflite | Local SQLite database |
| get_it | Dependency injection |
| equatable | State and value comparison |
| uuid | Client-generated identifiers |
| connectivity_plus | Network connectivity detection |
| sqflite_common_ffi | In-memory SQLite testing |
| bloc_test / mocktail | BLoC testing and mocking |

### Why sqflite instead of drift?

I chose **sqflite** because the assignment requires direct control over SQLite transactions, SQL queries, joins, aggregate queries, indexes and database migrations.

It also makes it straightforward to demonstrate:
- Transactional order submission.
- Atomic shipment planning and cancellation.
- SQL-based filtering and availability checks.
- Product totals using `GROUP BY`.
- Explicit v1-to-v2 database migration.

The trade-off is that SQL and mapping code must be maintained manually rather than generated.

## 2. Features

### Order management
- Search stores using a database `LIKE` query.
- Select shipment date and delivery time.
- Validate store delivery windows.
- Enter gallons for individual tanks.
- Validate integer quantities against available tank ullage.
- Display order gallon totals.
- Save and resume order drafts.
- Review and submit orders.
- Create an outbox event when an order is submitted.

### Shipment management
- Select submitted orders by shipment date.
- Display selected gallons grouped by product.
- Select available trucks and eligible drivers.
- Warn when selected gallons exceed truck capacity.
- Allocate order lines to truck compartments.
- Enforce compartment capacity and product matching.
- Require a reason for partial or zero allocations.
- Display requested, allocated and remaining gallons.
- Select a pickup terminal.
- Validate unique BOL numbers in `BOL-12345` format.
- Plan shipments transactionally.
- Cancel planned shipments and restore eligible orders.
- Display shipment conflict information and recovery actions.

### Database and offline support
- Seed reference data from `assets/data/seed.json`.
- Enable SQLite foreign-key enforcement.
- Use database transactions for critical operations.
- Maintain an outbox for order and shipment operations.
- Support database schema migration from v1 to v2.

## 3. Architecture

The application follows a layered architecture:

```text
UI (Flutter Pages and Widgets)
             |
             v
       BLoC Layer
             |
             v
    Repository Interface
             |
             v
 Repository Implementation
             |
             v
        DAO Layer
             |
             v
       SQLite Database
```

### Layer responsibilities

**Presentation**
- Flutter screens and reusable widgets.
- Form controls and user interactions.
- Displays immutable BLoC states.

**BLoC**
- Handles user events.
- Coordinates application workflows.
- Performs state transitions and validation coordination.
- Contains no SQL queries.

**Repository**
- Defines domain-facing data contracts.
- Connects BLoCs to data implementations.

**DAO**
- Contains SQL queries and database operations.
- Handles joins, filters, aggregates and transactions.

**Core**
- Database initialization and migrations.
- Dependency injection.
- Database change notifications.

## 4. Project Structure

```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart
│   │   └── database_change_notifier.dart
│   └── di/
│
├── data/
│   ├── dao/
│   ├── models/
│   └── repositories/
│
├── domain/
│   └── repositories/
│
├── features/
│   ├── dashboard/
│   ├── orders/
│   │   ├── bloc/
│   │   └── pages/
│   └── shipments/
│       ├── bloc/
│       └── pages/
│
└── main.dart

assets/
└── data/
    └── seed.json

test/
├── bloc/
├── dao/
├── database/
└── validators/
```

## 5. Database Design

### ER diagram

```text
STORES
  |
  | 1
  |------< TANKS >------ PRODUCTS
  |
  | 1
  |------< ORDERS
              |
              | 1
              |------< ORDER_LINES >------ TANKS
              |
              |------< SHIPMENT_ORDERS >------ SHIPMENTS
                                                  |
                                                  |------ TRUCKS
                                                  |          |
                                                  |          |------< COMPARTMENTS
                                                  |
                                                  |------ DRIVERS
                                                  |
                                                  |------ TERMINALS
                                                  |
                                                  |------< SHIPMENT_LOADS
                                                  |
                                                  |------< OUTBOX

ORDER_LINES
    |
    |------< SHIPMENT_LOADS >------ COMPARTMENTS
```

### Important database decisions

- Foreign keys maintain relationships between operational records.
- Indexes support common filters and lookups.
- Shipment list queries use joins and aggregate subqueries to calculate order counts and loaded gallons.
- Product totals are calculated in SQL using `GROUP BY`.
- BOL numbers have a unique database index.
- Nullable v2 fields preserve compatibility with existing v1 records.

### Database migration

**Version 1**
- Initial reference and transaction tables.
- Git tag: `v1`.

**Version 2**
- Adds `orders.po_number TEXT NULL`.
- Adds `shipments.bol_number TEXT NULL`.
- Adds a unique index for non-null BOL values.
- Preserves existing records during migration.

The migration is covered by an automated test using existing v1 data.

## 6. State Management

State is separated according to responsibility.

| State location | Responsibility |
|---|---|
| Form controls | Temporary text input, selection and field interaction |
| BLoC | Current wizard step, selected entities, validation results, loading and error states |
| SQLite | Persistent orders, order lines, shipments, allocations and outbox records |

This separation keeps widgets focused on presentation and avoids using the database as temporary form state.

BLoC states are immutable and updated through state transitions.

## 7. Important Transaction Handling

### Order submission

Order submission updates the order status and creates its outbox event in one database transaction.

```text
DRAFT
  |
  v
SUBMITTED
  |
  +----> OUTBOX event
```

### Shipment planning

Shipment planning is performed atomically:

1. Insert the shipment as `PLANNED`.
2. Insert shipment loads.
3. Update included orders to `SCHEDULED`.
4. Insert the shipment outbox event.

If an error occurs, the transaction rolls back.

A debug option allows testing failure after load insertion.

### Shipment cancellation

Cancellation updates the shipment to `CANCELLED`, restores eligible scheduled orders to `SUBMITTED`, and creates an outbox event in one transaction.

## 8. Running the Application

### Requirements
- Flutter 3.41.9 or compatible stable version.
- Dart 3.11.5 or compatible version.
- Android Studio or Android SDK.
- Android emulator or physical Android device.

### Setup

Clone the repository:

```bash
git clone https://github.com/sunildholpuria123/jobbersoft_orders.git
cd jobbersoft_orders
```

Install dependencies:

```bash
flutter pub get
```

Check the environment:

```bash
flutter doctor
```

Run the application:

```bash
flutter run
```

Run static analysis:

```bash
flutter analyze
```

Run all tests:

```bash
flutter test --reporter expanded
```

## 9. Automated Tests

The test suite covers database, DAO, migration, validation and BLoC behaviour.

| Test area | Tests passed |
|---|---:|
| Database and migration | 5 |
| Order DAO | 14 |
| Shipment DAO | 10 |
| Order validators | 13 |
| Tank validators | 9 |
| Order BLoC | 15 |
| Shipment Wizard BLoC | 23 |
| **Total** | **89** |

DAO tests use an in-memory SQLite database through `sqflite_common_ffi`.

Important scenarios covered include:
- Truck and driver availability.
- Product totals using SQL grouping.
- Shipment aggregate queries.
- BOL uniqueness.
- Order submission and outbox creation.
- Transaction rollback conditions.
- v1-to-v2 migration with existing records.
- Wizard state transitions and validation.

**Latest verification:** `flutter test` completed with all 89 tests passing, and `flutter analyze` reported no issues.

## 10. Assumptions and Known Gaps

- The application is designed primarily for Android, as required by the assignment.
- Shipment drafts are not part of the core MUST scope.
- The fake sync service, retry policy, connectivity-triggered processing and complete conflict scenarios should be verified against all assignment acceptance criteria before treating sync as fully complete.
- Automated widget and small-screen layout coverage can be expanded.
- A production deployment would replace the fake sync service with a real API implementation.

## 11. AI Tool Usage

AI tools were used as development assistants for:
- Reviewing assignment requirements and breaking them into implementation steps.
- Discussing database schema and migration design.
- Generating and reviewing SQL queries.
- Troubleshooting Flutter, Dart and SQLite issues.
- Preparing DAO, validator and BLoC tests.
- Reviewing documentation and code quality.

All generated code and changes were reviewed, executed and tested locally. AI assistance does not replace understanding the implementation; the project is prepared for further technical review and live changes.

## 12. Future Improvements

- Complete and harden background outbox synchronization.
- Add production API integration.
- Expand widget and integration tests.
- Improve accessibility and tablet layouts.
- Add shipment manifest export.
- Add automated compartment allocation.

---

**Project:** JobberSoft Orders & Shipments  
**Framework:** Flutter  
**Database:** SQLite  
**Architecture:** DAO → Repository → BLoC → UI
