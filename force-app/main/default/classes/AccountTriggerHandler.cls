public inherited sharing class AccountTriggerHandler {

    public AccountTriggerHandler() {
        System.debug(LoggingLevel.INFO, 'Account trigger now ready!');
    }

    public void run() {
        handleOwnershipChange();
        handleZipCodeChange();
    }

    private void handleZipCodeChange() {

        // First we will check if we are in a trigger context. Else the trigger
        // variables won't be available (like Trigger.new)
        // Check trigger variables here: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm

        // Second we check if the context is what we expect. We want to
        // handle the change only on insert and update operations.

        if (Trigger.isExecuting && Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {


            // I'm getting this ready to receive the map of old records if we are in an
            // update context. Otherwise this will be null (and we won't use it).

            Map<Id, Account> previousVersionsOfTheAccountRecords;

            if (Trigger.isUpdate) {
                // If this is an update, certainly we can get the old versions of the records
                // into the map, so we can use it below

                previousVersionsOfTheAccountRecords = (Map<Id, Account>) Trigger.oldMap;
            }

            // Let's create a list to store the accounts which need our attention
            List<Account> accountsWithModifiedZipCodes = new List<Account>();

            // Next let's iterate the records in this transaction and look for
            // our accounts.
            for (Account record : (List<Account>) Trigger.new) {

                // If this is an 'insert' operation there's no need to check if the
                // zip code was modified. We only check if it was specified by the
                // user or not.

                if (Trigger.isInsert && String.isNotBlank(record.BillingPostalCode)) {
                    accountsWithModifiedZipCodes.add(record);
                }

                if (Trigger.isUpdate) {

                    Account previousVersionOfTheAccountRecord = previousVersionsOfTheAccountRecords.get(record.Id);

                    if (record.BillingPostalCode != previousVersionOfTheAccountRecord.BillingPostalCode) {

                        // If the zip code was modified, this account also needs our attention.

                        accountsWithModifiedZipCodes.add(record);
                    }
                }
            }

            handleModifiedZipCodeAccounts(accountsWithModifiedZipCodes);
        }
    }

    /**
     * Handles account with modified zip codes.
     */
    private void handleModifiedZipCodeAccounts(List<Account> accountsWithModifiedZipCodes) {

        // Check if the parameter passed is null or empty. If it is either of those, then no
        // further execution is required for this method. Let's save some CPU time, shall we?

        if (accountsWithModifiedZipCodes == null || accountsWithModifiedZipCodes.isEmpty()) {
            return;
        }

        // I'll be using a set to store the zip codes found in the accounts. We'll need them
        // to query the territories.
        Set<String> zipCodes = new Set<String>();

        // I'm also going to sort the accounts by the territory so we can avoid a nested loop
        // below, after querying the territories.

        Map<String, List<Account>> accountsByTerritory = new Map<String, List<Account>>();

        // To populate that map, I'll iterate the accounts. I'm also going to get the zip codes
        // while at it.

        for (Account record : accountsWithModifiedZipCodes) {
            zipCodes.add(record.BillingPostalCode);

            // If this is the first time querying the map for a specific zip code, then initialize
            // that map key with an empty list. We'll add the current account to the list below.
            // If the map contains the key, then it has been initialized and has an account. In this
            // case we'll just add the account.

            if (!accountsByTerritory.containsKey(record.BillingPostalCode)) {
                accountsByTerritory.put(record.BillingPostalCode, new List<Account>());
            }

            // Get the list, add the current account to it, and put it back to the map for the next
            // iteration.

            List<Account> accountsInThatTerritory = accountsByTerritory.get(record.BillingPostalCode);
            accountsInThatTerritory.add(record);
            accountsByTerritory.put(record.BillingPostalCode, accountsInThatTerritory);
        }

        // Query the territories and store to a variable;
        List<Territory__c> territories = [
            SELECT Id, Name, OwnerId
            FROM Territory__c
            WHERE Name IN :zipCodes
        ];

        // Initialize an empty list of modified accounts so we don't update all of them.

        List<Account> modifiedAccounts = new List<Account>();

        // Knowing which territories we are using, and having a map of accounts per territory,
        // we'll improve the performance of a nested loop, and just check if the accounts
        // have an existing zip code

        for (Territory__c territoryRecord : territories) {

            // Check if we have accounts with this zip code

            if (accountsByTerritory.containsKey(territoryRecord.Name)) {

                for (Account record : accountsByTerritory.get(territoryRecord.Name)) {

                    // Requirement #2.A and 2.B:
                    // Change the Account Owner to the sales representative assigned to the new zip code.
                    // We don't need to change the contact's OwnerId because the relationship is
                    // a master-detail. The contact's owner will be the same of the account's.

                    record.OwnerId = territoryRecord.OwnerId;

                    modifiedAccounts.add(record);
                }
            }
        }

        // We now have the list of our modified accounts. If the owner changes, all the open opportunities
        // have to be transfered as well. We won't do this here. We'll write another method in our
        // account trigger handler to get that.

        // And since we are running this code in the `before` contet, the modified records will be
        // commited and then handled on the `after` context. No need for DMLs on the modified accounts.
    }

    /**
     * Handles the `OwnerId` change. If the account's owner is changed then all open opportunities
     * are to be transfered to the new owner. We'll want to do this in an `after update` context
     * since it makes no sense to do so in an `insert` context (the opportunities can't exist without
     * an account).
     */
    private void handleOwnershipChange() {

        if (Trigger.isExecuting && Trigger.isUpdate) {

            // We are sure this is an `update` context, so we get the old version of the records
            // ready to check for the change.

            Map<Id, Account> previousVersionsOfTheAccountRecords = (Map<Id, Account>) Trigger.oldMap;

            // Create a list to store the accounts with modified owner.
            List<AccountOwnershipChange> accountOwnershipChanges = new List<AccountOwnershipChange>();

            for (Account record : (List<Account>) Trigger.new) {

                Account previousVersionOfTheAccountRecord = previousVersionsOfTheAccountRecords.get(record.Id);

                if (previousVersionOfTheAccountRecord.OwnerId != record.OwnerId) {

                    // The owner has been changed. So we'll get this account to a method that
                    // handles that, as per requirement 2C.

                    accountOwnershipChanges.add(new AccountOwnershipChange(
                        record,
                        record.OwnerId,
                        previousVersionOfTheAccountRecord.OwnerId
                    ));
                }
            }

            handleAccountTransfer(accountOwnershipChanges);
        }
    }

    /**
     * Handles the account transfer. The open opportunities have to be transfered to the new owner.
     */
    private void handleAccountTransfer(List<AccountOwnershipChange> ownershipChanges) {

        // Check if the parameter passed is null or empty. If it is either of those, then no
        // further execution is required for this method. Let's save some CPU time, shall we?

        if (ownershipChanges == null || ownershipChanges.isEmpty()) {
            return;
        }

        // I'll build a map of user ids to user ids. Old owners to new owners.

        Map<Id, Id> propertyTransferMap = new Map<Id, Id>();

        // We'll need to get the user ids to query the opportunities later.

        Set<Id> previousOwnersIds = new Set<Id>();

        for (AccountOwnershipChange aoc : ownershipChanges) {
            previousOwnersIds.add(aoc.getPreviousOwnerId());

            if (!propertyTransferMap.containsKey(aoc.getPreviousOwnerId())) {
                propertyTransferMap.put(aoc.getPreviousOwnerId(), aoc.getNewOwnerId());
            }
        }

        // Select all the open opportunities owned by the old users
        List<Opportunity> openOpportunities = [
            SELECT Id, OwnerId
            FROM Opportunity
            WHERE StageName != 'Closed Won'
            AND StageName != 'Closed Lost'
            AND OwnerId IN :previousOwnersIds
        ];

        // Create a separate list for modified opportunities

        List<Opportunity> modifiedOpportunitites = new List<Opportunity>();

        for (Opportunity openOpportunity : openOpportunities) {

            // check if this opportunity should have a new owner, based on the map
            // built previously
            if (propertyTransferMap.containsKey(openOpportunity.OwnerId)) {

                // if it does, assign the new user
                openOpportunity.OwnerId = propertyTransferMap.get(openOpportunity.OwnerId);

                modifiedOpportunitites.add(openOpportunity);
            }
        }

        // Update opportunities that now have a new owner.
        update modifiedOpportunitites;
    }

    /**
     * Assign randomly the accounts.
     */
    private void randomAssignment(List<Account> accounts) {
        List<User> availableUsers = [SELECT Id FROM User WHERE IsActive = TRUE];

        for (Account record : accounts) {
            record.OwnerId = availableUsers.get(Math.round(Math.random() * (availableUsers.size() - 1)));
        }
    }

    /**
     * This inner class adds a little bit of OOP to the code. I'll be using this to store the account
     * and the previous and new owner. We'll need this to query the opportunities.
     */
    public class AccountOwnershipChange {

        private Account record;
        private Id newOwnerId;
        private Id previousOwnerId;

        public AccountOwnershipChange(Account record, Id newOwnerId, Id previousOwnerId) {

            this.record = record;
            this.newOwnerId = newOwnerId;
            this.previousOwnerId = previousOwnerId;

        }

        private Id getNewOwnerId() {
            return this.newOwnerId;
        }

        private Id getPreviousOwnerId() {
            return this.previousOwnerId;
        }
    }
}
