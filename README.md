# Solution for "Final Project" of the Salesforce Development Curriculum

## Requirements

1. Recreate the Zip Code spreadsheet as a custom Territory object. The custom object should have the custom fields defined in the original document.
2. Do things when an Account’s BillingPostalCode (aka Zip Code), is changed (see below list). The logic should run only when the Account’s zip code is changed or populated for the first time. If no matching Territories are found, do nothing.
3. Multiple sales representatives can be assigned to the same zip code territory. If this is the case, use a random function to select one of the assigned sales representatives.
4. Three sales representatives at most can be assigned to a single zip code. Display an error if a user attempts to associate another sales representative to a zip code.
5. Create an Assignment History custom object with the following fields.
6. Create an Assignment_History__c record whenever an Account’s BillingPostalCode is changed or populated for the first time. All fields should be populated.
7. If a Territory__c record’s sales representative is changed (and only when it is changed), repeat Requirement #2’s logic for all Accounts associated with the Territory.
8. At least 90% test code coverage.


### Things to do when an account's BillingPostalCode field changes:

1. Change the Account Owner to the sales representative assigned to the new zip code
2. Change the Owner field of all the Account’s Contacts to the same sales rep
3. Change the Owner field of all the Account’s Open Opportunities to the same sales rep

# Explanation

## Requirement #1

_Recreate the Zip Code spreadsheet as a custom Territory object. The custom object should have the custom fields defined in the original document._

The assignment tells us to recreate a zip code spreadsheet as a **custom object**. It explicitly tells us that the object should have the code as the `Name` field and the owner will be the standard `OwnerId` lookup. No mistery here.

## Requirement #2

_Do things when an Account’s BillingPostalCode (aka Zip Code), is changed. The logic should run only when the Account’s zip code is changed or populated for the first time. If no matching Territories are found, do nothing._

The first thing to consider here is whether you can solve this with declarative tools or not. Flows definitely can be used here, but since this is a development assignment, I'll be using Apex.

We'll want a trigger on the account object to check if the zip code is changed. We are talking pre-commit logic here, so ideally this will be put on `before insert` and `before update` contexts. No need to worry about the `after` context for now. The `Owner` will be set on the `before` context so we don't need to issue another DML to update the record (it is read-only in the `after` context anyway).

We don't need to change the contact's OwnerId because the Contact relationship with the related Account record is _Master-Detail_. Therefore, the Account's owner will automatically be the same as the related contacts.

## Requirement #3

_Multiple sales representatives can be assigned to the same zip code territory. If this is the case, use a random function to select one of the assigned sales representatives_

Now this changes a bit the assignment process. We'll need to query the available users and randomly assign then. It isn't explicit if we should query users with a given profile, role, permission set or custom permission. For now, we'll query all active users. One can change the requirements as necessary in a real scenario.

## Requirement #4

_Three sales representatives at most can be assigned to a single zip code. Display an error if a user attempts to associate another sales representative to a zip code._

The assignment tells us to check if a user is trying to own more than three `Territory__c` records. We'll create a validation logic on a new trigger handler, on the custom territory object. Instead of querying all the related records and all the users, we'll use aggregation to get the territory count per user using the `AggregateResult` query result object.

## Requirements #5

_Create an Assignment History custom object with the following fields:_

|Field name|Field type|Description|
|---|---|---|
|Previous Owner|Lookup (User)|The prior sales rep assigned to this Account|
|New Owner|Lookup (User)|The new sales rep assigned to this Account|
|Previous Territory|Lookup (Territory__c)|The matching Territory__c record for the prior zip code|
|New Territory|Lookup (Territory__c)|The matching Territory__c record for the new zip code|
|Account|Master-Detail (Account)|The related Account record|
|Changed By|Lookup (User)|The user who changed the BillingPostalCode|

I am not creating the `Changed By` field because the record will be created by the user performing the operation. So the standard `CreatedById` field will be always available as a lookup to the user who made the change

## Requirement #6

_Create an `Assignment_History__c` record whenever an Account’s BillingPostalCode is changed or populated for the first time. All fields should be populated._

For this I'll have to change the account's trigger to include this field tracking. Since the requirement is to do this when changed or populated for the first time, this means an `update` and `insert` logic. All fields should be populated since when the zip code changes the owner will also change.

## Requirement #7

_If a `Territory__c` record’s sales representative is changed (and only when it is changed), repeat Requirement #2’s logic for all Accounts associated with the Territory._
