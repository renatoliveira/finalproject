@IsTest
private class TerritoryTriggerHandlerTest {

    @TestSetup
    static void setupData() {

        List<String> repsNames = new List<String>{
            'Blake',
            'Jacqueline',
            'Denise',
            'Aaron'
        };
        List<User> users = new List<User>();

        for (String repName : repsNames) {

            User userRecord = new User(
                Alias = repName.left(8),
                Email= repName.toLowerCase() + '.standarduser@testorg.com',
                EmailEncodingKey='UTF-8',
                FirstName = repName,
                LastName='Testing',
                LanguageLocaleKey='en_US',
                LocaleSidKey='en_US',
                ProfileId = UserInfo.getProfileId(),
                TimeZoneSidKey='America/Los_Angeles',
                UserName= repName.toLowerCase() + '.standarduser@testorg.com'
            );

            users.add(userRecord);
        }

        insert users;
    }

    @IsTest
    static void testTerritoryTransferWithErrors() {
        // user currently has three territories. Assigning one more shouldn't be possible.

        Map<String, User> users = TerritoryTriggerHandlerTest.getUsersByName();

        System.runAs(users.get('Blake')) {
            List<Territory__c> territories = new List<Territory__c>();

            for (Integer i = 0; i < 3; i++) {
                Territory__c theTerritory = new Territory__c(
                    Name = '0000' + i,
                    OwnerId = users.get('Blake').Id
                );
                territories.add(theTerritory);
            }

            insert territories;
        }

        System.runAs(users.get('Denise')) {
            Territory__c theTerritory = new Territory__c(
                Name = '00009',
                OwnerId = users.get('Blake').Id
            );

            Test.startTest();

            try {
                insert theTerritory;
                System.assert(false, 'Should have thrown an exception.');
            } catch (DmlException e) {
                System.assert(true, 'Should have thrown an exception.');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testWhenNoTerritoriesAreDefinedYetWithNoErrors() {
        // In a single transaction try to insert less than three records and assign them to the same
        // user
        List<Territory__c> territories = new List<Territory__c>();

        for (Integer i = 0; i < 2; i++) {
            Territory__c theTerritory = new Territory__c(
                Name = '0000' + i
            );
            territories.add(theTerritory);
        }

        Test.startTest();

        try {
            insert territories;
            System.assert(true, 'Should not have thrown an exception.');
        } catch (DMLException e) {
            System.assert(false, 'Should not have thrown an exception.');
        }

        Test.stopTest();
    }

    @IsTest
    static void testWhenNoTerritoriesAreDefinedYet() {
        // In a single transaction try to insert more than three records and assign them to the same
        // user
        List<Territory__c> territories = new List<Territory__c>();

        for (Integer i = 0; i < 4; i++) {
            Territory__c theTerritory = new Territory__c(
                Name = '0000' + i
            );
            territories.add(theTerritory);
        }

        Test.startTest();

        try {
            insert territories;
            System.assert(false, 'Should have thrown an exception.');
        } catch (DMLException e) {
            System.assert(true, 'Should have thrown an exception.');
        }

        Test.stopTest();
    }

    @IsTest
    static void testWhenExistingTerritoriesAreDefined() {

        List<Territory__c> territories = new List<Territory__c>();

        for (Integer i = 0; i < 3; i++) {
            Territory__c theTerritory = new Territory__c(
                Name = '0000' + i
            );
            territories.add(theTerritory);
        }

        insert territories;

        Test.startTest();

        Territory__c theTerritory = new Territory__c(
            Name = '00010'
        );

        try {
            insert theTerritory;
            System.assert(false, 'Should have thrown an exception.');
        } catch (DMLException e) {
            System.assert(true, 'Should have thrown an exception.');
        }

        Test.stopTest();
    }

    private static Map<String, User> getUsersByName() {
        Map<String, User> users = new Map<String, User>();
        for (User u : [
            SELECT Id, FirstName, LastName
            FROM User
            WHERE Email LIKE '%.standarduser@testorg.com']) {
            users.put(u.FirstName, u);
        }
        return users;
    }
}
