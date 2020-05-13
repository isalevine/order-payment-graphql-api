# README

## Overview
This Order Payment GraphQL API is a Rails app that accepts GraphQL queries and mutations. It uses [`Order`](https://github.com/isalevine/order-payment-graphql-api#order) and [`Payment`](https://github.com/isalevine/order-payment-graphql-api#payment) models, as well as a [`PendingOrderPayment`](https://github.com/isalevine/order-payment-graphql-api#pendingorderpayment) model to join them (as well as provide idempotency-checking and status updates). 

The models can be illustrated as:

`Order --< PendingOrderPayment >-- Payment`

and described as:

_"An Order has many Payments through PendingOrderPayments."_

`Orders` are not accessed by their sequential ID. Instead, they have a `reference_key` String field, with a unique, random UUID. **This value must be used when adding a** `Payment` **to an** `Order` **!**

`Payments` are checked for idempotency by having a unique, random UUID for their `idempotency_key`. `PendingOrderPayments` are created with a matching `idempotency_key`. If a `Payment` is sent multiple times, an existing `PendingOrderPayment` with the same `idempotency_key` will catch the duplication and handle it appropriately (either decline the `Payment`, or retry applying it to the `Order`).

The API accepts one GraphQL query, `allOrders`, and two GraphQL mutations, `createOrder` and `createPayment`. See the [**Queries**](https://github.com/isalevine/order-payment-graphql-api#queries) and [**Mutations**](https://github.com/isalevine/order-payment-graphql-api#mutations) sections below for more information.

All primary goals were achieved. No stretch goals were achieved within the given timeframe. See [**Assumptions**](https://github.com/isalevine/order-payment-graphql-api#assumptions), notes under each [**Model**](https://github.com/isalevine/order-payment-graphql-api#models), and the [**Work Summary**](https://github.com/isalevine/order-payment-graphql-api#work-summary) below for more information on design choices, challenges encountered, and refactoring goals.


## Highlights
* **Idempotency implemented for all payment transactions [via the use of UUIDs!](https://github.com/isalevine/order-payment-graphql-api/blob/dead714af93a9e945e468f32d4bf9611e6920177/app/graphql/mutations/create_payment.rb#L34)** 
  
  This required learning about best practices for implementing idempotency in APIs.

* **The Order model has its `has_many :payments` relationship [expanded with filtering via a `do` block!](https://github.com/isalevine/order-payment-graphql-api/blob/f71839655162b711ecdaf6d10c0978c80f935a0a/app/models/order.rb#L6)** 
  
  Customizing `has_many` blocks is a useful (and often unheard-of) way to add functionality accessible via dot notation, i.e. `Order.payments.successful`.

* **I learned GraphQL from scratch and created this API in 8 hours!** 
  
  [See the breakdown of time spent,](https://github.com/isalevine/order-payment-graphql-api/blob/master/README.md#breakdown-of-time-spent) as well as [steps to learn GraphQL](https://github.com/isalevine/order-payment-graphql-api/blob/master/README.md#breakdown-of-time-spent) and the [resources used.](https://github.com/isalevine/order-payment-graphql-api/blob/master/README.md#breakdown-of-time-spent)

* **This served as the basis for my 3rd-most-viewed Dev.to blog, [a tutorial for creating a Rails GraphQL API from scratch!](https://dev.to/isalevine/ruby-on-rails-graphql-api-tutorial-from-rails-new-to-first-query-76h)** 

  This is part of a three-blog series that also includes [creating GraphQL mutations](https://dev.to/isalevine/ruby-on-rails-graphql-api-tutorial-creating-data-with-mutations-39ab), and [two ways to filter GraphQL data!](https://dev.to/isalevine/ruby-on-rails-graphql-api-tutorial-filtering-with-custom-fields-and-class-methods-3efd)


## Setup
Clone this repo. You will need **Ruby 2.6.1** and **Rails 5.2.3** installed.

Run `bundle install` inside the main /order-payment-graphql-api/ directory to install Rails and dependencies.

To create the database, run `rails db:create` to create the SQLite development database, followed by `rails db:migrate` to run the Rails migrations, and finally `rails db:seed` to add seed data.

Run `rails s` to start the Rails server. Calls to the API are made to `http://localhost:3000/graphql`.


## Executing Queries and Mutations
Queries and mutations can be sent to the API using **`http://localhost:3000/graphql`** and a tool like the [Insomnia REST client](https://insomnia.rest/)


### Queries
* **allOrders** -- return all `Orders`:
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


## Models

### `Order`
* Model fields:
  * description (string)
  * total (float)
  * reference_key (string) -- random UUID used to mask sequential ID; **use this field for Order lookup**
  * created_at (datetime)
  * updated_at (datetime)

* Custom Model methods:
  * balance_due -- returns value of `Order` `total` minus the `amounts` of all "Successful" `Payments`

* Custom GraphQL fields:
  * successful_payments -- return only `Payments` that have a `PendingOrderPayment` with `status` "Successful"
  * pending_payments -- return only `Payments` that have a `PendingOrderPayment` with `status` "Pending"
  * failed_payments -- return only `Payments` that have a `PendingOrderPayment` with `status` "Failed"

* Notes:
  * `payments` and `pending_order_payments` fields are disabled -- uncomment fields in /app/graphql/types/order_type.rb to enable queries


### `Payment`
* Model fields:
  * amount (float)
  * note (string) -- optional
  * idempotency_key (string) -- random UUID used to identify duplicate `Payments` by checking `PendingOrderPayment`'s idempotency_key
    * **Resubmitted mutations should NOT generate a new idempotency_key**, thus allowing duplicates to be caught
  * created_at (datetime)
  * updated_at (datetime)

* Notes:
  * Currently using `created_at` field as GraphQL::Types::ISO8601DateTime in lieu of `applied_at` in spec
  * Ideally, would refactor to be updated after an `Order`'s `balanceDue` is calculated and confirmed to have applied the `Payment` `amount`


### `PendingOrderPayment`
* Model fields:
  * order_id (integer)
  * payment_id (integer)
  * idempotency_key (string) -- random UUID used to identify duplicate `Payments` by checking `PendingOrderPayment`'s idempotency_key
  * status (string)
    * created as "Pending"
    * set to "Successful" when applied to Order
    * set to "Failed" when a duplicate Payment is caught

* Notes:
  * Currently, `status` is set to "Successful" while verifying the change to an `Order`'s `balanceDue` -- this could cause errors!
  * Possible solutions:
    1. Create another `Order` method like `pendingBalanceDue`, which can calculate the incoming `Payment`'s amount while the `PendingOrderPayment`'s `status` is "Pending"
    1. Create another `status` like `Being Applied` that can be used with `balanceDue` while keeping the "Successful" `Payments` separate


## Assumptions
1. Idempotency for `Payments` is implemented by generating a unique, random UUID (the `idempotency_key` field on `Payment` and `PendingOrderPayment`) as part of the `resolve()` method the CreatePayment mutation. **This assumes that errors resulting in sending the same API call multiple times HAS THE SAME idempotency_key!**
  * Testing for catching non-unique idempotency_keys involved mocking creating a `Payment` with a non-unique string.
  * More testing is needed to mock specific API call errors! (i.e. the EXACT SAME call being made twice due to a network interruption)

1. All access to the API is already authenticated -- assume that creating orders and adding payments are both user-authenticated, and that querying for all orders is an admin privilege.

1. All Float math will eventually need to be refactored -- either make into Integer math (and output by formatting with 2-decimal Float), or do some .floor() rounding.


## Primary Goals
In addition to the basic requirements of the challenge, there are several implementation goals I have. These pertain specifically to the API Extras **"Don't expose auto-incrementing IDs through your API"** and **"All mutations should be idempotent"**:

* Use `reference_key` (randomly-generated UUID) to mask models' ids, and as primary `Order` identifier for mutations

* Use `idempotency_key` (randomly-generated UUID) with both `Payment` and `PendingOrderPayment` models to ensure that transactions are not duplicated, and provide more explicit error handling.
  * This strategy is owed to the "Track Requests" strategy in this article: https://engineering.shopify.com/blogs/engineering/building-resilient-graphql-apis-using-idempotency

* "Order has_many Payments through PendingOrderPayments" -- Use `PendingOrderPayment`'s statuses ("Successful", "Pending", "Failed") to filter/organize payments returned by queries
  * ex. Only `Payments` with a "Successful" `PendingOrderPayment` will be calculated for `Order`'s `balance_due` field.


## Stretch Goals
* Add handling for `Payments` exceeding `Order` totals
  * In the `Order` balanceDue query field, address by making minimum value 0.00
    * Include a returned message about "Payment amounts exceed Order total!"
  * **Alternately**, could block `Payment` before exceeding balanceDue
    * Could also *change* `Payment` amount to the remaining balanceDue, and return a message saying "Payment amount reduced to not exceed balanceDue!"

* **"Provide an atomic "place order and pay" mutation"** -- Ensure that all 3 models are valid before mutating database, else return error and persist no data

* **"Explore subscriptions"** -- Use Rails' ActionMailer (completely new to me)

* Add queries to search for `PendingOrderPayments` with "Failed" or "Pending" status

* Provide alternative to `reference_key` for Order lookup by implementing username/password/lookupKeyword fields on `Order` and the mutation to create `Payments`, or adding a `User` model with `has_secure_password` to explicitly handle authentication



## Work Summary

### Insights on Challenge
* **How did you feel about it overall?** -- I really enjoyed this challenge! I appreciate opportunities to dive into a new technology, and GraphQL has been a great tool to explore. After working with it, I appreciate its strong typing (especially working in Ruby), and how intuitive it is to write queries and mutations once set up.

* **What was the hardest part?** -- Implementing idempotency! I wanted to follow [the "Track Requests" strategy in this article on idempotency](https://engineering.shopify.com/blogs/engineering/building-resilient-graphql-apis-using-idempotency), and created the `PendingOrderPayment` to handle payment `statuses` and store `idempotency_keys`.

  It was easy enough to add a unique key to `Payments`, but needing to load/instantiate a `PendingOrderPayment` object and check its `idempotency_key`--all during the resolve() method call in the `createPayment` mutation--became a complicated process. Given more time, I would certainly revisit this database structure, and seek more guidance on idempotency.

  Additionally, managing the `status` of the `PendingOrderPayment` led to non-atomic API calls, which is definitely sub-optimal. However, it did allow me to easily filter for `successfulPayments` on `Order` (as well as `pendingPayments` and `failedPayments`, if needed).

* **What parts did you enjoy the most?** -- Building out custom methods on the `Order` model, especially the ones nested under the `has_many-through` relationship! As part of using the `PendingOrderPayment` `status` to filter `Payments`, I was able to define custom functions to chain ActiveRecord filters onto the `Payments` belonging to a given `Order`.

  I had never implemented ActiveRecord chaining/filtering directly on a model like that, and it ultimately made the `Order` model a lot more powerful, particularly in the `createPayment`'s complicated resolve() method. I'm excited to revisit this and go deeper in my personal Rails projects!

  I also enjoyed wrestling with how to implement idempotency! Though I don't think I have an optimal solution, I now know more about what strategies and issues to consider when trying to avoid duplicating API mutations.

* **What shortcomings do you feel your solution currently has?** -- I know that the idempotency for `createPurchase` mutations needs to be more thoroughly tested. Most testing was done by mocking `Payments` with a non-unique `idempotency_key`, but more specific scenarios need to be tested (i.e. a `Payment` being submitted twice due to a network interruption).

  I also know that the `PendingOrderPayment` `status` field is not used optimally (i.e. being set to "Successful" in order to check that it updates an `Order`'s `balance_due` accurately). I would like to revisit and refactor the methods to check `balance_due` and update `status`, and ideally make them more atomic (i.e. only change `status` once). On a larger scale, I would also like to revisit the `PendingOrderPayment` model for handling idempotency, and seek out more experienced advice on implementing it efficiently (or completely refactoring to a different database structure).

* **What would you do next if you had more time to build it out?** --
  1. Refactor all Float math into Integer math, and format outputs as Floats with two decimal places.

  1. Explore different ways to handle `idempotency_key` -- try storing keys from successful `Payments` directly on `Order`?

  1. Build additional queries/mutations to fetch pending/failed payments, and either resolve or delete them?

  1. Build more handling into `Payments` that put an `Order`'s balance below zero -- automatically revise `Payment` `amounts` and return a message to the user?

  1. Add an atomic operation to create a new `Order` and `Payment` at the same time.

  1. Explore subscriptions (and more other `Order`-lookup strategies) with a password-protected `User` model, and the ActiveMailer gem.

  1. Add user/admin authentication to queries/mutations (instead of assuming they are handled outside of this app).


### Breakdown of Time Spent
* 1 hour - Reading documentation and familiarizing with GraphQL
* 2 hours - Creating practice app with GraphQL Rails tutorial
* 5 hours - Creating, testing, and refactoring main app
* 1 hour - Adding final documentation and process notes to Readme


### Learning GraphQL

Steps included:
* Reading documentation on GraphQL and its Ruby implementations with Rails and ActiveRecord
* Reading tutorials and creating a practice app
* Taking handwritten notes to summarize practice, and list specific goals and strategies


### Resources Used
* Rails GraphQL practice tutorial: [https://mattboldt.com/2019/01/07/rails-and-graphql/](https://mattboldt.com/2019/01/07/rails-and-graphql/)
  * GitHub repo with practice app: [https://github.com/isalevine/graphql-ruby-practice/settings](https://github.com/isalevine/graphql-ruby-practice/settings)

* Filtering has_many-through relationships: [https://stackoverflow.com/a/9547179](https://stackoverflow.com/a/9547179)

* Implementing idempotency (see the "Track Requests" strategy): https://engineering.shopify.com/blogs/engineering/building-resilient-graphql-apis-using-idempotency

* GraphQL Ruby docs: [https://graphql-ruby.org/guides](https://graphql-ruby.org/guides)


