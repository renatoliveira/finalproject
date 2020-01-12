// This trigger is called "Custom Territory" because Salesforce has a standard object called
// Territory as well.
trigger CustomTerritory on Territory__c (before insert, before update, after update) {
    new TerritoryTriggerHandler().run();
}