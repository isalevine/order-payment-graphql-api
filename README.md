# README



## Overview


### Models

#### `Order`
    * Model fields:
        * description (string)
        * total (float)
        * reference_key (string) -- random UUID used to mask sequential ID; **use this field for Order lookup**
        * created_at (datetime)
        * updated_at (datetime)

    * Custom Model methods:
        * balance_due -- returns value of `Order` `total` minus the `amount`s of all "Successful" `Payment`s

    * Custom GraphQL fields:
        * successful_payments -- return only `Payments` that have a `PendingOrderPayment` with `status` "Successful"
        * pending_payments -- return only `Payments` that have a `PendingOrderPayment` with `status` "Pending"
        * failed_payments -- return only `Payments` that have a `PendingOrderPayment` with `status` "Failed"

    * Notes:
        * `payments` and `pending_order_payments` fields are disabled -- uncomment fields in /app/graphql/types/order_type.rb to enable queries


#### `Payment`
    * Model fields:
        * amount (float)
        * note (string) -- optional
        * idempotency_key (string) -- random UUID used to identify duplicate `Payment`s by checking `PendingOrderPayment`'s idempotency_key
            * **Resubmitted mutations should NOT generate a new idempotency_key**, thus allowing duplicates to be caught
        * created_at (datetime)
        * updated_at (datetime)

    * Notes:
        * Currently using `created_at` field as GraphQL::Types::ISO8601DateTime in lieu of `applied_at` in spec
        * Ideally, would refactor to be updated after an `Order`'s `balanceDue` is calculated and confirmed to have applied the `Payment` `amount`


#### `PendingOrderPayment`
    * Model fields:
        * order_id (integer)
        * payment_id (integer)
        * idempotency_key (string) -- random UUID used to identify duplicate `Payment`s by checking `PendingOrderPayment`'s idempotency_key
        * status (string)
            * created as "Pending"
            * set to "Successful" when applied to Order
            * set to "Failed" when a duplicate Payment is caught

    * Notes:
        * Currently, `status` is set to "Successful" while verifying the change to an `Order`'s `balanceDue` -- this could cause errors!
        * Possible solutions:
            1. Create another `Order` method like `pendingBalanceDue`, which can calculate the incoming `Payment`'s amount while the `PendingOrderPayment`'s `status` is "Pending"
            1. Create another `status` like `Being Applied` that can be used with `balanceDue` while keeping the "Successful" `Payments` separate


### Assumptions

1. Idempotency for `Payment`s is implemented by generating a unique, random UUID (the `idempotency_key` field on `Payment` and `PendingOrderPayment`) as part of the `resolve()` method the CreatePayment mutation. **This assumes that errors resulting in sending the same API call multiple times HAS THE SAME idempotency_key!**
    * Testing for catching non-unique idempotency_keys involved mocking creating a `Payment` with a non-unique string.
    * More testing is needed to mock specific API call errors! (i.e. the EXACT SAME call being made twice due to a network interruption)
1. All access to the API is already authenticated -- assume that creating orders and adding payments are both user-authenticated, and that querying for all orders is an admin privilege.
1. All Float math will eventually need to be refactored -- either make into Integer math (and output by formatting with 2-decimal Float), or do some .floor() rounding.


### Primary Goals

In addition to the basic requirements of the challenge, there are several implementation goals I have. These pertain specifically to the API Extras **"Don't expose auto-incrementing IDs through your API"** and **"All mutations should be idempotent"**:

* Use `reference_key` (randomly-generated UUID) to mask models' ids, and as primary `Order` identifier for mutations
* Use `idempotency_key` (randomly-generated UUID) with both `Payment` and `PendingOrderPayment` models to ensure that transactions are not duplicated, and provide more explicit error handling
* "Order has_many Payments through PendingOrderPayments" -- Use `PendingOrderPayment`'s statuses ("Successful", "Pending", "Failed") to filter/organize payments returned by queries
    * ex. Only `Payment`s with a "Successful" `PendingOrderPayment` will be calculated for `Order`'s `balance_due` field.


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

* **`http://localhost:3000/graphql`** and a tool like the [Insomnia REST client](https://insomnia.rest/)
* ~~The [GraphiQL IDE](https://github.com/graphql/graphiql) and `http://localhost:3000/graphiql` in-browser~~ <= **This app was created with --skip-sprockets, so the 'graphiql' gem is not configured to work!**


### Queries

* **allOrders** -- return all `Order`s:
```
query {
  allOrders {
      referenceKey
      description
      total
      balanceDue
      successfulPayments {
        amount
        note
        createdAt
      }
      pendingPayments {
        amount
        note
        createdAt
      }
      failedPayments {
        amount
        note
        createdAt
      }
  }
}
```


### Mutations

* **createOrder** -- create and return a new `Order`, with the following arguments:
    * description (string)
    * total (float) -- **Currently not verified to be a 2-digit float! May refactor to be an integer, and avoid float-math**
```
mutation {
  createOrder(input: {
    description: "Espresso Vivace beans, Vita roast",
    total: 17.00
  }) {
    order {
      referenceKey
      description
      total
      balanceDue
      successfulPayments {
        amount
        note
        createdAt
      }
    }
    errors
  }
}
```

* **createPayment** -- create a new `Payment` and return its `Order`, with the following arguments:
    * referenceKey (string) -- UUID to identify `Order`
    * amount (float)
    * note (string) -- optional
```
mutation {
  createPayment(input: {
    referenceKey: "f22fcee8-1ffd-42f2-9834-3022bc1c3d3f",
    amount: 0.05,
    note: "First installment"
  }) {
    order {
      referenceKey
      description
      total
      balanceDue
      successfulPayments {
        amount
        note
        createdAt
      }
    }
    errors
  }
}
```




## Work Summary


### Learning GraphQL

Steps included:
* Reading documentation on GraphQL and its Ruby implementations with Rails and ActiveRecord
* Reading tutorials and creating a practice app
* Taking handwritten notes to summarize practice, and list specific goals and strategies


### Resources Used

* Rails GraphQL practice tutorial: https://mattboldt.com/2019/01/07/rails-and-graphql/
    * GitHub repo with practice app: https://github.com/isalevine/graphql-ruby-practice/settings

* Filtering has_many-through relationships: https://stackoverflow.com/a/9547179

* 


