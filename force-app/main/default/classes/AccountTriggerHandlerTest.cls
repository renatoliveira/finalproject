@IsTest
private class AccountTriggerHandlerTest {

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
    static void testZipChange() {
        // Jacqueline is assigned to territory 00000. Blake owns an account and will
        // change the zip code to '00000'. The account should be transfered to Jacqueline.

        Map<String, User> users = AccountTriggerHandlerTest.getUsersByName();

        Territory__c jaquelinesTerritory = new Territory__c(
            Name = '00000',
            OwnerId = users.get('Jacqueline').Id
        );
        Territory__c blakesTerritory = new Territory__c(
            Name = '00001',
            OwnerId = users.get('Blake').Id
        );

        insert new List<Territory__c>{
            jaquelinesTerritory,
            blakesTerritory
        };

        String accountName = 'Cool Motors, LLC';

        System.runAs(users.get('Blake')) {
            // say blake creates an account

            Account coolMotors = new Account(
                Name = accountName,
                OwnerId = users.get('Blake').Id
            );
            insert coolMotors;

            // and he will transfer it to Jacqueline's territory

            coolMotors.BillingPostalCode = jaquelinesTerritory.Name;

            Test.startTest();
            update coolMotors;
            Test.stopTest();
        }

        List<Account> jaquelinesAccounts = [
            SELECT Id, Name
            FROM Account
            WHERE OwnerId = :users.get('Jacqueline').Id
        ];

        System.assertEquals(1, jaquelinesAccounts.size(), 'Jaqueline should have an account assigned to her.');
        System.assertEquals(accountName, jaquelinesAccounts[0].Name, 'It should be the Cool Motors account.');
    }

    @IsTest
    static void testZipChangeWithNoTerritoryAssigned() {
        // Jacqueline is assigned to territory 00000. Blake owns an account and will
        // change the zip code to '00003'. The account should not be transfered.

        Map<String, User> users = AccountTriggerHandlerTest.getUsersByName();

        Territory__c jaquelinesTerritory = new Territory__c(
            Name = '00000',
            OwnerId = users.get('Jacqueline').Id
        );
        Territory__c blakesTerritory = new Territory__c(
            Name = '00001',
            OwnerId = users.get('Blake').Id
        );

        insert new List<Territory__c>{
            jaquelinesTerritory,
            blakesTerritory
        };

        String accountName = 'Cool Motors, LLC';

        System.runAs(users.get('Blake')) {
            // say blake creates an account

            Account coolMotors = new Account(
                Name = accountName,
                OwnerId = users.get('Blake').Id
            );
            insert coolMotors;

            // and he will transfer it to a territory which nobody owns

            coolMotors.BillingPostalCode = '00003';

            Test.startTest();
            update coolMotors;
            Test.stopTest();
        }

        List<Account> blakesAccounts = [
            SELECT Id, Name
            FROM Account
            WHERE OwnerId = :users.get('Blake').Id
        ];

        System.assertEquals(1, blakesAccounts.size(), 'Blake should have an account assigned to him.');
        System.assertEquals(accountName, blakesAccounts[0].Name, 'It should be the Cool Motors account.');
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
