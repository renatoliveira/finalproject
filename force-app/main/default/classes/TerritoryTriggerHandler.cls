public inherited sharing class TerritoryTriggerHandler {

    public TerritoryTriggerHandler() {
        System.debug('Territory trigger handler now ready to run!');
    }

    public void run() {
        if (Trigger.isBefore) {
            validateAssignment();
        }
    }

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
}
