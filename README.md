# README



## Overview


### Models

* `Order`

* `Payment`

* `PendingOrderPayment`


### Assumptions

1. All access to the API is already authenticated -- assume that creating orders and adding payments are both user-authenticated, and that querying for all orders is an admin privilege.


### Primary Goals

In addition to the basic requirements of the challenge, there are several implementation goals I have. These pertain specifically to the API Extras **"Don't expose auto-incrementing IDs through your API"** and **"All mutations should be idempotent"**:

* Use `reference_key` (randomly-generated UUID) to mask models' ids, and as primary `Order` identifier for mutations
* Use `idempotency_key` (randomly-generated UUID) with both `Payment` and `PendingOrderPayment` models to ensure that transactions are not duplicated, and provide more explicit error handling
* "Order has_many Payments through PendingOrderPayments" -- Use `PendingOrderPayment`'s statuses ("Successful", "Pending", "Failed") to filter/organize payments returned by queries
    * ex. Only `Payment`s with a "Successful" `PendingOrderPayment` will be calculated for `Order`'s `balanceDue` field.


### Stretch Goals

* Add handling for `Payment`s exceeding `Order` totals
    * In the `Order` balanceDue query field, address by making minimum value 0.00
        * Include a returned message about "Payment amounts exceed Order total!"
    * **Alternately**, could block `Payment` before exceeding balanceDue
        * Could also *change* `Payment` amount to the remaining balanceDue, and return a message saying "Payment amount reduced to not exceed balanceDue!"
* **"Provide an atomic "place order and pay" mutation"** -- Ensure that all 3 models are valid before mutating database, else return error and persist no data
* **"Explore subscriptions"** -- Use Rails' ActionMailer (completely new to me)
* Add queries to search for `PendingOrderPayment`s with "Failed" or "Pending" status
* Provide alternative to `reference_key` for Order lookup by implementing username/password/lookupKeyword fields on `Order` and the mutation to create `Payment`s, or adding a `User` model with `has_secure_password` to explicitly handle authentication




## Setup

Run `bundle install` to install Rails and dependencies.

To create the database, run `rails db:create` to create the SQLite development database, followed by `rails db:migrate` to run the Rails migrations and finally `rails db:seed` to add seed data.

Run `rails s` to run the Rails server. Calls to the API can be made to `http://localhost:3000/graphql`.




## Executing Queries and Mutations

Queries and mutations can be sent to the API using: 

* `http://localhost:3000/graphql` and a tool like the [Insomnia REST client](https://insomnia.rest/)
* ~~The [GraphiQL IDE](https://github.com/graphql/graphiql) and `http://localhost:3000/graphiql` in-browser~~ **This app was created with --skip-sprockets, so graphiql gem not configured to work!**


### Queries


### Mutations





## Work Summary

### Learning GraphQL

Steps included:
* Reading documentation on GraphQL and its Ruby implementations with Rails and ActiveRecord
* Reading tutorials and creating a practice app
* Taking handwritten notes to summarize practice, and list specific goals and strategies

### Resources Used


