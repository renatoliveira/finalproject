public inherited sharing class TerritoryTriggerHandler {

    public TerritoryTriggerHandler() {
        System.debug('Territory trigger handler now ready to run!');
    }

    public void run() {
        validateAssignment();
        handleOwnershipChange();
    }

    /**
     * Chechks if the user can have the territory assigned to them. They can't have more than
     * three territories assigned.
     */
    private void validateAssignment() {
        if (Trigger.isExecuting && Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {

            Set<Id> ownersIds = new Set<Id>();

            for (Territory__c record : (List<Territory__c>) Trigger.new) {
                ownersIds.add(record.OwnerId);
            }

            List<AggregateResult> territoryPerPersonRecords = [
                SELECT
                COUNT(Id)c,
                OwnerId
                FROM Territory__c
                WHERE OwnerId IN :ownersIds
                GROUP BY OwnerId
            ];

            Map<Id, Integer> territoryPerPerson = new Map<Id, Integer>();

            for (AggregateResult ar : territoryPerPersonRecords) {

                territoryPerPerson.put(Id.valueOf(String.valueOf(ar.get('OwnerId'))), Integer.valueOf(String.valueOf(ar.get('c'))));
            }

            for (Territory__c record : (List<Territory__c>) Trigger.new) {
                if (territoryPerPerson.containsKey(record.OwnerId) && territoryPerPerson.get(record.OwnerId) >= 3) {
                    record.addError('It is not possible to assign more than three territories to a user!');
                }

                if (!territoryPerPerson.containsKey(record.OwnerId)) {
                    territoryPerPerson.put(record.OwnerId, 0);
                }

                Integer currentTerritoriesForThisOwner = territoryPerPerson.get(record.OwnerId);
                territoryPerPerson.put(record.OwnerId, currentTerritoriesForThisOwner + 1);
            }
        }
    }

    private void handleOwnershipChange() {

        if (Trigger.isExecuting && Trigger.isAfter) {

            Map<Id, Territory__c> previousTerritoryRecords = (Map<Id, Territory__c>) Trigger.oldMap;
            List<Territory__c> territoriesWithOwnerChanged = new List<Territory__c>();

            for (Territory__c record : (List<Territory__c>) Trigger.new) {
                Territory__c previousVersion = previousTerritoryRecords.get(record.Id);

                // Make our life easier by not allowing the user to change the owner AND the zip code
                // at the same time. They will have to update those in separate transactions

                if (previousVersion.OwnerId != record.OwnerId && previousVersion.Name != record.Name) {
                    record.addError('Please change either the owner or name. Not both at the same edit.');
                }

                if (previousVersion.OwnerId != record.OwnerId) {
                    territoriesWithOwnerChanged.add(record);
                }
            }

            transferAccounts(territoriesWithOwnerChanged);
        }
    }

    private void transferAccounts(List<Territory__c> territories) {

        Set<String> zipCodes = new Set<String>();

        for (Territory__c record : territories) {
            zipCodes.add(record.Name);
        }

        List<Account> accounts = [
            SELECT
            Id, BillingPostalCode
            FROM Account
            WHERE BillingPostalCode IN :zipCodes
        ];

        Map<String, List<Account>> accountsByTerritory = new Map<String, List<Account>>();

        // To populate that map, I'll iterate the accounts. I'm also going to get the zip codes
        // while at it.

        for (Account record : accounts) {
            if (!accountsByTerritory.containsKey(record.BillingPostalCode)) {
                accountsByTerritory.put(record.BillingPostalCode, new List<Account>());
            }

            List<Account> accountsInThatTerritory = accountsByTerritory.get(record.BillingPostalCode);
            accountsInThatTerritory.add(record);
            accountsByTerritory.put(record.BillingPostalCode, accountsInThatTerritory);
        }

        List<Account> accountsWithNewOwners = new List<Account>();

        for (Territory__c record : territories) {
            if (accountsByTerritory.containsKey(record.Name)) {
                for (Account accountRecord : accountsByTerritory.get(record.Name)) {
                    accountRecord.OwnerId = record.OwnerId;
                    accountsWithNewOwners.add(accountRecord);
                }
            }
        }

        update accountsWithNewOwners;
    }
}
