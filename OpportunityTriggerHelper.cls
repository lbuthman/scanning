/**
 * @author CloudMasonry
 * @description Trigger Helper class used by the OpportunityTriggerHandler
 */
public with sharing class OpportunityTriggerHelper {
    static final Integer CUTOFF_HOURS_FOR_BUYER_SELLER_DATE = Integer.valueOf(
        System.Label.CutOffHoursForBuyerSellerDate
    );
    static final Time DST_TIME = Time.newInstance(2, 0, 0, 0);
    public static final String STAGENAME_APPROVED_TO_RESELL = 'Approved to Resell',
        STAGENAME_CANCELLATION_APPROVED = 'Cancellation Approved',
        STAGENAME_CANCELLATION_SUBMITTED = 'Cancellation Submitted',
        STAGENAME_CLOSED_WON = 'Closed Won',
        STAGENAME_CLOSED_LOST = 'Closed Lost',
        STAGENAME_CONTRACT_PENDING = 'Contract Pending',
        STAGENAME_CONTRACTED = 'Contracted',
        STAGENAME_CANCELLED = 'Cancelled',
        STAGENAME_DISCOVERY = 'Discovery',
        STAGENAME_ESCROW = 'Escrow',
        STAGENAME_HOLD = 'Hold',
        STAGENAME_OFFER_APPROVED = 'Offer Approved',
        STAGENAME_OFFER_PENDING = 'Offer Pending',
        STAGENAME_PENDING_CANCELLATION = 'Pending Cancellation',
        STAGENAME_PENDING_TRANSFER = 'Pending Transfer',
        STAGENAME_PREQUALIFICATION = 'Prequalification',
        STAGENAME_PROPOSAL_DRAFT = 'Proposal/Draft',
        STAGENAME_RESERVATION = 'Reservation',
        CANCELAPPROVALSTATUS_PENDING = 'Pending',
        CANCELAPPROVALSTATUS_APPROVED = 'Approved',
        CANCELAPPROVALSTATUS_SAVED = 'Saved',
        CANCELAPPROVALSTATUS_REJECTED = 'Rejected',
        CANCELAPPROVALSTATUS_RECALLED = 'Recalled',
        CANCELAPPROVALSTATUS_DRAFT = 'Draft',
        RECORDTYPE_CANCELLED = 'Cancelled',
        RECORDTYPE_OPEN = 'Open',
        RECORDTYPE_ESCROW = 'Escrow',
        QUOTE_STAGENAME_CONTRACTPENDINGAPPROVED = 'ContractPendingApprovedQuote',
        QUOTE_STAGENAME_APPROVED = 'Approved',
        QUOTE_STAGENAME_DRAFT = 'Draft',
        QUOTE_STAGENAME_CLOSED = 'Closed',
        QUOTE_STATUS_APPROVED = 'Approved',
        QUOTE_STATUS_DRAFT = 'Draft';
    static final Map<String, Schema.RecordTypeInfo> MAP_OPPORTUNITY_RECORDTYPE_BY_DEVELOPERNAME = Opportunity.SobjectType.getDescribe()
        .getRecordTypeInfosByDeveloperName();
    static final Map<String, Schema.RecordTypeInfo> MAP_QUOTE_RECORDTYPE_BY_DEVELOPERNAME = SBQQ__Quote__c.SobjectType.getDescribe()
        .getRecordTypeInfosByDeveloperName();

    /*
     * @description Wrapper class to callculate rollup fields for the Broker
     */
    private class brokerRollupWrapper {
        Integer openCount;
        Integer closedWonCount;
        Decimal openTotal;
        Decimal closedWonTotal;
        List<Opportunity> listOpportunity;

        public Integer opportunityCount {
            get {
                return listOpportunity.size();
            }
            set;
        }

        /**
         * @description Constructor for the Rollup, initializes the values in the wrapper
         */
        public brokerRollupWrapper() {
            listOpportunity = new List<Opportunity>();
            openCount = 0;
            closedWonCount = 0;
            openTotal = 0;
            closedWonTotal = 0;
        }

        /**
         * @description Method to add Opportunities to the wrapper and calculate the rollup values
         * @param   thisOpportunity    Opportunity Record
         */
        public void addOpportunity(Opportunity thisOpportunity) {
            this.listOpportunity.add(thisOpportunity);
            if (
                thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                thisOpportunity.StageName == STAGENAME_CLOSED_WON
            ) {
                this.closedWonCount++;
                if (thisOpportunity?.Amount != null) {
                    this.closedWonTotal += thisOpportunity.Amount;
                }
            } else if (thisOpportunity.StageName != STAGENAME_CLOSED_LOST) {
                this.openCount++;
                if (thisOpportunity?.Amount != null) {
                    this.openTotal += thisOpportunity.Amount;
                }
            }
        }
    }

    /**
     * @description Method to fetch Accounts Mapped by Id
     * @param   setAccountIds    Set Account Ids
     * @return  Map of requeried Opportunities by Id
     */
    public static Map<Id, Account> fetchAccount(Set<Id> setAccountIds) {
        List<Account> listAccounts = [SELECT Id, Affiliated__c, Type FROM Account WHERE Id IN :setAccountIds];
        return new Map<Id, Account>(listAccounts);
    }

    /**
     * @description Method to fetch contacts mapped by Id
     * @param   setContactIds Set of Contact Ids
     * @return  Reference Map of Contacts keyed By its Id
     */
    public static Map<Id, Contact> fetchContacts(Set<Id> setContactIds) {
        Map<Id, Contact> mapContactById = new Map<Id, Contact>();
        if(!setContactIds.isEmpty()) {
            List<Contact> listContacts = [
                SELECT Id, OwnerId, Contact_Status__c, Name, Email, AccountId, MailingCountry
                FROM Contact
                WHERE Id IN :setContactIds
            ];
            mapContactById.putall(listContacts);
        }
        return mapContactById;
    }

    /**
     * @description Method to fetch contacts mapped by Account Id
     * @param   setAccountIds Set of Account Ids
     * @return  Reference Map of Contacts grouped by the Account Id
     */
    public static Map<Id, List<Contact>> fetchContactsFromAccountIds(Set<Id> setAccountIds) {
        Map<Id, List<Contact>> mapContactsByAccountId = new Map<Id, List<Contact>>();
        for (Contact thisContact : [
            SELECT
                Id,
                OwnerId,
                Contact_Status__c,
                Name,
                Email,
                AccountId,
                Account_Type__c,
                Closed_Lost_Reason_H__c,
                Closed_Lost_Reason__c,
                Disqualified_Reason_H__c,
                Disqualified_Reason__c,
                Revert_Reason_H__c,
                Revert_Reason__c
            FROM Contact
            WHERE AccountId IN :setAccountIds
        ]) {
            if (!mapContactsByAccountId.containsKey(thisContact.AccountId)) {
                mapContactsByAccountId.put(thisContact.AccountId, new List<Contact>());
            }
            mapContactsByAccountId.get(thisContact.AccountId).add(thisContact);
        }
        return mapContactsByAccountId;
    }

    /**
     * @description Method to fetch Opportunities mapped by Account Id
     * @param   setAccountIds Set of Account Ids
     * @return  Reference Map of Opportunities grouped by the Account Id
     */
    public static Map<Id, List<Opportunity>> fetchAllOpportunitiesByAccount(Set<Id> setAccountIds) {
        Map<Id, List<Opportunity>> mapOpportunitiesByAccountId = new Map<Id, List<Opportunity>>();
        for (Opportunity thisOpportunity : [
            SELECT Id, AccountId, Closed_Lost_Reason__c, StageName
            FROM Opportunity
            WHERE AccountId IN :setAccountIds
        ]) {
            if (!mapOpportunitiesByAccountId.containsKey(thisOpportunity.AccountId)) {
                mapOpportunitiesByAccountId.put(thisOpportunity.AccountId, new List<Opportunity>());
            }
            mapOpportunitiesByAccountId.get(thisOpportunity.AccountId).add(thisOpportunity);
        }
        return mapOpportunitiesByAccountId;
    }

    /**
     * @description Method to fetch Opportunities mapped by Broker Account Id
     * @param   setAccountIds Set of Account Ids
     * @return  Reference Map of Opportunities grouped by the Account Id
     */
    public static Map<Id, List<Opportunity>> fetchAllOpportunitiesByBroker(Set<Id> setAccountIds) {
        Map<Id, List<Opportunity>> mapOpportunitiesByBrokerId = new Map<Id, List<Opportunity>>();
        for (Opportunity thisOpportunity : [
            SELECT Id, StageName, Amount, Broker_s_Name__c
            FROM Opportunity
            WHERE Broker_s_Name__c IN :setAccountIds
        ]) {
            if (!mapOpportunitiesByBrokerId.containsKey(thisOpportunity.Broker_s_Name__c)) {
                mapOpportunitiesByBrokerId.put(thisOpportunity.Broker_s_Name__c, new List<Opportunity>());
            }
            mapOpportunitiesByBrokerId.get(thisOpportunity.Broker_s_Name__c).add(thisOpportunity);
        }
        return mapOpportunitiesByBrokerId;
    }

    /**
     * @description Method to fetch Opportunities mapped by Home Site Id
     * @param   setAccountIds Set of Account Ids
     * @return  Reference Map of Opportunities grouped by the Home Site Id
     */
    public static Map<Id, List<Opportunity>> fetchAllOpportunitiesByHomeSite(Set<Id> setHomeSiteIds) {
        Map<Id, List<Opportunity>> mapOpportunitiesByBrokerId = new Map<Id, List<Opportunity>>();
        for (Opportunity thisOpportunity : [
            SELECT Id, Name, StageName, Home_Site__c, Home_Site_Lookup__c, Homesite_Sales_Status__c
            FROM Opportunity
            WHERE Home_Site_Lookup__c IN :setHomeSiteIds
        ]) {
            if (!mapOpportunitiesByBrokerId.containsKey(thisOpportunity.Home_Site_Lookup__c)) {
                mapOpportunitiesByBrokerId.put(thisOpportunity.Home_Site_Lookup__c, new List<Opportunity>());
            }
            mapOpportunitiesByBrokerId.get(thisOpportunity.Home_Site_Lookup__c).add(thisOpportunity);
        }
        return mapOpportunitiesByBrokerId;
    }

    /**
     * @description Method to fetch Community Sites mapped by Id
     * @param   setCommunitySiteIds Set of Community Site Ids
     */
    public static Map<Id, Community_Site__c> fetchCommunitySites(Set<Id> setCommunitySiteIds) {
        List<Community_Site__c> listCommunitySites = [
            SELECT Id, Name, Average_Sales_Price__c, Active__c, Phase_2_Division__c,  
            Additional_Terms_Addendum__c, Anne_Arundel_County_Addendum__c, Buyer_is_ordering_options__c, 
            Conditional_Public_Report_Addendum__c, Condominium_Addendum__c, Deposit_Disclosure__c, Design_Studio__c,
            Designer__c, Escrow_Company__c, Closing_Agent_Representative__c,
            Frederick_County_Addendum__c, General_Disclosure_Addendum__c, General_Escrow_Instructions_Addendum__c, 
            Homeowners_Association_Addendum__c, Incentive_Addendum__c, Independent_Inspectors_Policy_Addendum__c, 
            Mineral_and_Oil_and_Gas_Rights_Mandatory__c, Model_Home_Addendum__c, Montgomery_County_Addendum__c, 
            Montgomery_County_Disclosure_of_Property__c, New_Home_Warranty_Plan_Disclosure__c, Occupancy_Addendum__c, 
            Options_Addendum__c, Options_to_be_Added__c, Other_Addendum__c, Post_Closing_Dispute_Resolution_Addendum__c, 
            Solar_Energy_System_Addendum__c, Statute_of_Limitations_Addendum__c, Title_Company_Name__c, Title_Company_Representative__c,
            Water_and_Sewer_Charges_Addendum__c, Approver__c, Construction_Admin__c, Director_of_Sales__c, Approver_2__c, 
            Approver_3__c, Approver_4__c, Division_President__c, Escrow_Coordinator__c, NHS__c, Purchasing_Admin__c,
            TRI_Pointe_Connect__c, VP_of_Construction__c, VP_of_Sales__c
            FROM Community_Site__c
            WHERE Id IN :setCommunitySiteIds
        ];
        return new Map<Id, Community_Site__c>(listCommunitySites);
    }

    /**
     * @description Method to fetch Quote mapped by Id
     * @param   setQuoteIds Set of Quote Ids
     */
    public static Map<Id, SBQQ__Quote__c> fetchQuotes(Set<Id> setQuoteIds) {
        List<SBQQ__Quote__c> listQuotes = [
            SELECT
                Id,
                Name,
                Total_Final_Purchase_Price__c,
                SBQQ__Primary__c,
                Home_Site_Lookup__c,
                Floor_Plan_Lookup__c,
                Phase_Lookup__c,
                RecordTypeId,
                SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            WHERE Id IN :setQuoteIds
        ];
        return new Map<Id, SBQQ__Quote__c>(listQuotes);
    }

    /**
     * @description Method to fetch Quotes by Opportunity Id
     * @param   setOpportunityIds Set of Opportunity Ids
     * @return  List of Opportuntities
     */
    public static List<SBQQ__Quote__c> fetchQuotesByOpportunityId(Set<Id> setOpportunityIds) {
        List<SBQQ__Quote__c> listQuotes = [
            SELECT
                Id,
                Name,
                Total_Final_Purchase_Price__c,
                SBQQ__Primary__c,
                Home_Site_Lookup__c,
                Floor_Plan_Lookup__c,
                Phase_Lookup__c,
                SBQQ__Status__c,
                RecordTypeId,
                SBQQ__Opportunity2__c,
                Base_Price__c,
                Homesite_Premium__c,
                Management_Price_Adjustment__c,
                Pre_Plotted_Options__c,
                Buyer_Selected_Options__c,
                Discounts__c,
                Frozen_Base_Price__c,
                Frozen_Lot_Premium__c,
                Frozen_Mgmt_Adjustment__c,
                Frozen_Customer_Selected_Option__c,
                Frozen_Discount__c
            FROM SBQQ__Quote__c
            WHERE SBQQ__Opportunity2__c IN :setOpportunityIds
        ];
        return listQuotes;
    }
    /**
     * @description Method to Group Quotes by Opportunity Id
     * @param   setOpportunityIds Set of Opportunity Ids
     * @return  reference map of Quotes grouped by Opportunity Ids
     */
    public static Map<Id, List<SBQQ__Quote__c>> groupQuotesByOpportunityId(List<SBQQ__Quote__c> listQuotes) {
        Map<Id, List<SBQQ__Quote__c>> mapQuotesGroupByOpportunityId = new Map<Id, List<SBQQ__Quote__c>>();
        for (SBQQ__Quote__c thisQuote : listQuotes) {
            if (!mapQuotesGroupByOpportunityId.containsKey(thisQuote.SBQQ__Opportunity2__c)) {
                mapQuotesGroupByOpportunityId.put(thisQuote.SBQQ__Opportunity2__c, new List<SBQQ__Quote__c>());
            }
            mapQuotesGroupByOpportunityId.get(thisQuote.SBQQ__Opportunity2__c).add(thisQuote);
        }

        return mapQuotesGroupByOpportunityId;
    }

    /**
     * @description Method to fetch Site Visits Mapped by Account Id, and sorted by Arrival Time
     * @param   setAccountIds Set of Account Ids
     */
    public static Map<Id, List<Site_Visit__c>> fetchSiteVisitsKeyedByAccountId(Set<Id> setAccountIds) {
        Map<Id, List<Site_Visit__c>> mapSiteVisitsByAccountId = new Map<Id, List<Site_Visit__c>>();
        for (Site_Visit__c thisSiteVisit : [
            SELECT Id, Account__c, Contact__c, Agent_Account__c, First_Visit_With_Agent__c, Community_Site__c
            FROM Site_Visit__c
            WHERE Account__c IN :setAccountIds
            ORDER BY Arrival_Time__c ASC
        ]) {
            if (!mapSiteVisitsByAccountId.containsKey(thisSiteVisit.Account__c)) {
                mapSiteVisitsByAccountId.put(thisSiteVisit.Account__c, new List<Site_Visit__c>());
            }
            mapSiteVisitsByAccountId.get(thisSiteVisit.Account__c).add(thisSiteVisit);
        }
        return mapSiteVisitsByAccountId;
    }

    /**
     * @description Overload method that takes in a list of Opportuntiies
     * @param   listNewOpportunities    Trigger.New
     */
    public static Map<Id, List<OpportunityContactRole>> fetchOpportunityContactRolesMapKeyedByOpportunityId(
        List<Opportunity> listNewOpportunities
    ) {
        Map<Id, Opportunity> mapOpportunityByIds = new Map<Id, Opportunity>(listNewOpportunities);
        return fetchOpportunityContactRolesMapKeyedByOpportunityId(mapOpportunityByIds.keySet());
    }

    /**
     * @description Method to fetch and generate a refrence map of OpportunityContactRoles keyed by the Opportunity Id
     * @param   setOpportunityIds   Set of Opportunity Ids
     */
    public static Map<Id, List<OpportunityContactRole>> fetchOpportunityContactRolesMapKeyedByOpportunityId(
        Set<Id> setOpportunityIds
    ) {
        Map<Id, List<OpportunityContactRole>> mapOpportunityContactRolesByOpportunityId = new Map<Id, List<OpportunityContactRole>>();
        for (OpportunityContactRole thisOpportunityContactRole : [
            SELECT Contact.Name, Contact.Email, Role, OpportunityId, ContactId
            FROM OpportunityContactRole
            WHERE OpportunityId IN :setOpportunityIds
            ORDER BY Role ASC, CreatedDate ASC
        ]) {
            if (!mapOpportunityContactRolesByOpportunityId.containsKey(thisOpportunityContactRole.OpportunityId)) {
                mapOpportunityContactRolesByOpportunityId.put(
                    thisOpportunityContactRole.OpportunityId,
                    new List<OpportunityContactRole>()
                );
            }
            mapOpportunityContactRolesByOpportunityId.get(thisOpportunityContactRole.OpportunityId)
                .add(thisOpportunityContactRole);
        }
        return mapOpportunityContactRolesByOpportunityId;
    }

    /**
     * @description Method to fetch and generate a refrence map of Docusign Statuses keyed by the Opportunity Id when
     *              Cancel_Approval_Status is updated to Saved
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunties      Trigger.oldMap
     */
    public static Map<Id, List<dsfs__DocuSign_Status__c>> fetchDocuSignsKeyedByOpportunityIdsWhenStatusEqualSaved(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties
    ) {
        Set<Id> setOpportunityIds = new Set<Id>();
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            if (
                thisOpportunity.Cancel_Approval_Status__c != oldOpportunity?.Cancel_Approval_Status__c &&
                thisOpportunity.Cancel_Approval_Status__c == CANCELAPPROVALSTATUS_SAVED
            ) {
                setOpportunityIds.add(thisOpportunity.Id);
            }
        }
        Map<Id, List<dsfs__DocuSign_Status__c>> mapDocusignStatusesByOpportunityId = new Map<Id, List<dsfs__DocuSign_Status__c>>();
        for (dsfs__DocuSign_Status__c thisDocuSignStatus : [
            SELECT Id, dsfs__Opportunity__c, dsfs__Envelope_Status__c, Document_Type__c
            FROM dsfs__DocuSign_Status__c
            WHERE dsfs__Opportunity__c IN :setOpportunityIds
        ]) {
            if (!mapDocusignStatusesByOpportunityId.containsKey(thisDocuSignStatus.dsfs__Opportunity__c)) {
                mapDocusignStatusesByOpportunityId.put(
                    thisDocuSignStatus.dsfs__Opportunity__c,
                    new List<dsfs__DocuSign_Status__c>()
                );
            }
            mapDocusignStatusesByOpportunityId.get(thisDocuSignStatus.dsfs__Opportunity__c).add(thisDocuSignStatus);
        }
        return mapDocusignStatusesByOpportunityId;
    }

    /**
     * @description Method to fetch and generate a refrence map of NHA Assignments
     * @param   setCommunityIds     Set of Community Site Ids
     * @return  A set of NHA User Ids mapped by the Community Site Id
     */
    public static Map<Id, Set<Id>> fetchNhaAssignmentsUsers(Set<Id> setCommunityIds) {
        Map<Id, Set<Id>> mapNhaUsersByCommunityId = new Map<Id, Set<Id>>();
        for (NHA_Assignment__c thisAssignment : [
            SELECT NHA_User__c, Community_Site__c
            FROM NHA_Assignment__c
            WHERE
                Active__c = TRUE
                AND NHA_User__c != NULL
                AND NHA_User__r.IsActive = TRUE
                AND Community_Site__c IN :setCommunityIds
            LIMIT 1000
        ]) {
            if (!mapNhaUsersByCommunityId.containsKey(thisAssignment.Community_Site__c)) {
                mapNhaUsersByCommunityId.put(thisAssignment.Community_Site__c, new Set<Id>());
            }
            mapNhaUsersByCommunityId.get(thisAssignment.Community_Site__c).add(thisAssignment.NHA_User__c);
        }
        return mapNhaUsersByCommunityId;
    }

    /**
     * @description Method to fetch a list of Opportunity Share
     * @param   listNewOpportunities    Trigger.New
     * @return  A list of Opportunity Share Records
     */
    public static List<OpportunityShare> fetchOpportunityShare(List<Opportunity> listNewOpportunities) {
        List<OpportunityShare> listOpportunityShare = [
            SELECT Id, OpportunityAccessLevel, RowCause
            FROM OpportunityShare
            WHERE OpportunityId IN :listNewOpportunities AND RowCause = 'Team'
        ];
        return listOpportunityShare;
    }

    /**
     * @description Method to fetch a list of Auto Created Tasks
     * @param   setOpportunityIds    Set of Opportunity Ids
     * @return  A list of Task records
     */
    public static List<Task> fetchAutoCreatedTasks(Set<Id> setOpportunityIds) {
        List<Task> listTask = [
            SELECT Id, Status, Auto_Created__c
            FROM Task
            WHERE Auto_Created__c = TRUE AND WhatId IN :setOpportunityIds AND Status != 'Completed'
        ];
        return listTask;
    }

    /**
     * @description Method to fetch OpportunityLineItems to be deleted
     * @param   setOpportunityIds    Set of Opportunity Ids
     * @return  A list of OpportunityLineItems
     */
    public static List<OpportunityLineItem> fetchOpportunityLineItemsForDeletion(Set<Id> setOpportunityIds) {
        List<OpportunityLineItem> listOpportunityLineItems = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId IN :setOpportunityIds
        ];
        return listOpportunityLineItems;
    }

    /**
     * @description Method to fetch OpportunityTeamMember to be deleted
     * @param   listOpportunity    List of Opportunity records
     * @return  A list of OpportunityTeamMember
     */
    public static List<OpportunityTeamMember> fetchOpportunityTeamMembersForDeletion(
        List<Opportunity> listOpportunity
    ) {
        List<OpportunityTeamMember> listOpportunityTeamMembers = [
            SELECT Id
            FROM OpportunityTeamMember
            WHERE OpportunityId IN :listOpportunity
        ];
        return listOpportunityTeamMembers;
    }

    /**
     * @description Method to fetch and return a map of Priority List Entries grouped by Community Site filtered
     * @param   setCommunityIds    Set of Community Ids
     * @param   setBuyerContactIds    Set of Contact Ids
     * @return  A Map of Priority List Entry grouped by Community Site Ids
     */
    public static Map<Id, List<Priority_List_Entry__c>> fetchPriorityListEntryGroupedByCommunitySiteId(
        Set<Id> setCommunityIds,
        Set<Id> setBuyerContactIds
    ) {
        Map<Id, List<Priority_List_Entry__c>> mapPriorityListEntriesByCommunitySiteId = new Map<Id, List<Priority_List_Entry__c>>();
        if (!setCommunityIds.isEmpty() && !setBuyerContactIds.isEmpty()) {
            List<String> inactiveReasons = new List<String>{
                STAGENAME_CONTRACTED,
                STAGENAME_CLOSED_WON,
                STAGENAME_CLOSED_LOST
            };
            for (Priority_List_Entry__c thisPriorityListEntry : [
                SELECT Id, Priority_List__r.Community_Site__c, Buyer_Contact__c
                FROM Priority_List_Entry__c
                WHERE
                    (Status__c = 'Active'
                    OR (Status__c = 'Inactive'
                    AND Inactive_Reason__c IN :inactiveReasons))
                    AND Priority_List__r.Community_Site__c IN :setCommunityIds
                    AND Buyer_Contact__c IN :setBuyerContactIds
            ]) {
                if (
                    !mapPriorityListEntriesByCommunitySiteId.containsKey(
                        thisPriorityListEntry.Priority_List__r.Community_Site__c
                    )
                ) {
                    mapPriorityListEntriesByCommunitySiteId.put(
                        thisPriorityListEntry.Priority_List__r.Community_Site__c,
                        new List<Priority_List_Entry__c>()
                    );
                }
                mapPriorityListEntriesByCommunitySiteId.get(thisPriorityListEntry.Priority_List__r.Community_Site__c)
                    .add(thisPriorityListEntry);
            }
        }
        return mapPriorityListEntriesByCommunitySiteId;
    }

    /**
     * @description Method to fetch and return a map of Pre Closing Closing Milestones Group By Opportunity Ids
     * @param   setOpportunityIds    Set of Opportunity Ids
     * @return  A map of Pre Closing Closing Milestones Group By Opportunity Ids
     */
    public static Map<Id, List<Pre_Closing_Closing_Milestone__c>> fetchPCCMilestoneGroupByOpportunityId(
        Set<Id> setOpportunityIds
    ) {
        Map<Id, List<Pre_Closing_Closing_Milestone__c>> mapPCCMilestonesGroupByOpportunityId = new Map<Id, List<Pre_Closing_Closing_Milestone__c>>();
        for (Pre_Closing_Closing_Milestone__c pccMilestoneRecord : [
            SELECT Id, Probability1__c, LastModifiedDate, Opportunity__c, Opportunity__r.StageName
            FROM Pre_Closing_Closing_Milestone__c
            WHERE Opportunity__c IN :setOpportunityIds
        ]) {
            if (!mapPCCMilestonesGroupByOpportunityId.containsKey(pccMilestoneRecord.Opportunity__c)) {
                mapPCCMilestonesGroupByOpportunityId.put(
                    pccMilestoneRecord.Opportunity__c,
                    new List<Pre_Closing_Closing_Milestone__c>()
                );
            }
            mapPCCMilestonesGroupByOpportunityId.get(pccMilestoneRecord.Opportunity__c).add(pccMilestoneRecord);
        }
        return mapPCCMilestonesGroupByOpportunityId;
    }

    /**
     * @description Method to fetch and return a map of Quote Lines Group By Quote Ids
     * @param   setPrimaryQuoteIds    Set of Primary Quote Ids
     * @return  A mmap of Quote Lines Group By Quote Ids
     */
    public static Map<Id, List<SBQQ__QuoteLine__c>> fetchQuoteLinesGroupedByQuote(Set<Id> setPrimaryQuoteIds) {
        Map<Id, List<SBQQ__QuoteLine__c>> mapQuoteLinesGroupedByQuote = new Map<Id, List<SBQQ__QuoteLine__c>>();
        for (SBQQ__QuoteLine__c thisQuoteLine : [
            SELECT Id, Name, SBQQ__Quote__c, Product_Type__c, SBQQ__PriceEditable__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :setPrimaryQuoteIds
        ]) {
            if (!mapQuoteLinesGroupedByQuote.containsKey(thisQuoteLine.SBQQ__Quote__c)) {
                mapQuoteLinesGroupedByQuote.put(thisQuoteLine.SBQQ__Quote__c, new List<SBQQ__QuoteLine__c>());
            }
            mapQuoteLinesGroupedByQuote.get(thisQuoteLine.SBQQ__Quote__c).add(thisQuoteLine);
        }
        return mapQuoteLinesGroupedByQuote;
    }

    /**
     * @description Method to query Community Sites and PCC Templates to generatte a set of Ids that has related PCC Templates
     * @param   setCommunityIds    Set of Community Ids
     * @return  Set of Community Site Ids with PCC Templates
     */
    public static Map<Id, Id> getCommunityIdsWithPccTemplates(Set<Id> setCommunityIds) {
        Map<Id, Id> mapCommunitySiteIdByDivisionSiteId = new Map<Id, Id>();
        Map<Id, Id> mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates = new Map<Id, Id>();
        for (Community_Site__c thisCommunitySite : [
            SELECT Division_Setting__c
            FROM Community_Site__c
            WHERE Id IN :setCommunityIds AND Division_Setting__c != NULL
        ]) {
            mapCommunitySiteIdByDivisionSiteId.put(thisCommunitySite.Division_Setting__c, thisCommunitySite.Id);
        }
        for (Pre_Closing_Closing_Template__c thisTemplate : [
            SELECT Id, Division_Setting__c
            FROM Pre_Closing_Closing_Template__c
            WHERE Division_Setting__c IN :mapCommunitySiteIdByDivisionSiteId.keySet()
        ]) {
            Id communitySiteId = mapCommunitySiteIdByDivisionSiteId.get(thisTemplate.Division_Setting__c);
            mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates.put(
                communitySiteId,
                thisTemplate.Division_Setting__c
            );
        }
        return mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates;
    }

    /**
     * @description Method used in the Before Trigger context to calculate and set the Sales Ratified Date field
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunties      Trigger.oldMap
     */
    public static void setDateTimeFields(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties
    ) {
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            if (
                thisOpportunity.Purchase_Agreement_VP_Signed_Date__c != null &&
                oldOpportunity?.Purchase_Agreement_VP_Signed_Date__c == null
            ) {
                thisOpportunity.Sales_Ratified_Date__c = getEstDate(
                    thisOpportunity,
                    Opportunity.Purchase_Agreement_VP_Signed_Date__c
                );
            }

            if (
                thisOpportunity.Purchase_Agreement_VP_Signed_Date__c != null &&
                thisOpportunity.Sales_Ratified_Date__c != null &&
                thisOpportunity.Purchase_Agreement_VP_Signed_Date__c < thisOpportunity.Sales_Reported_Date__c
            ) {
                thisOpportunity.Sales_Ratified_Date__c = thisOpportunity.Sales_Reported_Date__c;
            }

            if (
                thisOpportunity.Purchase_Agreement_Buyer_Signed_Date__c != null &&
                thisOpportunity.Deposit_Received_Amount__c >= 1000 &&
                thisOpportunity.Deposit_Received__c == 'Yes' &&
                thisOpportunity.Sales_Reported_Date__c == null &&
                thisOpportunity.EarnestDepositReceivedDate__c != null
            ) {
                Date depositReceivedDate = thisOpportunity.EarnestDepositReceivedDate__c;
                Date agreementDate = getEstDate(thisOpportunity, Opportunity.Purchase_Agreement_Buyer_Signed_Date__c);
                if (depositReceivedDate > agreementDate) {
                    thisOpportunity.Sales_Reported_Date__c = depositReceivedDate;
                } else {
                    thisOpportunity.Sales_Reported_Date__c = agreementDate;
                }
                thisOpportunity.Days_b_w_Opp_created_and_contract__c = thisOpportunity.CreatedDate.date()
                    .daysBetween(thisOpportunity.Sales_Reported_Date__c);
            }
        }
    }

    /**
     * @description Method Used in the Before Trigger context to evaluate and set the StageName and RecordTypeId
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunties      Trigger.oldMap
     */
    public static void setStageNamesAndRecordType(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties
    ) {
        List<String> listEscrowContractedStageNames = new List<String>{
            STAGENAME_CONTRACT_PENDING,
            STAGENAME_CONTRACTED
        };
        List<String> listEscrowCancelApprovalStatuses = new List<String>{
            CANCELAPPROVALSTATUS_DRAFT,
            CANCELAPPROVALSTATUS_SAVED
        };

        List<String> listStatusesForCancelledRecordType = new List<String>{
            STAGENAME_CANCELLATION_SUBMITTED,
            STAGENAME_CANCELLATION_APPROVED,
            STAGENAME_PENDING_CANCELLATION,
            STAGENAME_CANCELLED,
            STAGENAME_APPROVED_TO_RESELL
        };

        List<String> listNewCancelApprovalStatus = new List<String>{
            CANCELAPPROVALSTATUS_SAVED,
            CANCELAPPROVALSTATUS_REJECTED,
            CANCELAPPROVALSTATUS_RECALLED
        };

        List<String> listOldCancelApprovalStatus = new List<String>{
            CANCELAPPROVALSTATUS_PENDING,
            CANCELAPPROVALSTATUS_APPROVED,
            CANCELAPPROVALSTATUS_DRAFT
        };

        for (Opportunity thisOpportunity : listNewOpportunities) {
            Decimal sumAmount =
                thisOpportunity.Earnest_Deposit_Received_Amount__c + thisOpportunity.Deposit_Received_Amount__c;
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            if (
                thisOpportunity.Purchase_Agreement_VP_Signed_Date__c != null &&
                thisOpportunity.Sales_Ratified_Date__c != null &&
                sumAmount > 0 &&
                listEscrowContractedStageNames.contains(thisOpportunity.StageName) &&
                oldOpportunity?.StageName != STAGENAME_ESCROW &&
                oldOpportunity?.IsClosed == false &&
                listEscrowCancelApprovalStatuses.contains(thisOpportunity.Cancel_Approval_Status__c)
            ) {
                thisOpportunity.StageName = STAGENAME_ESCROW;
            }

            if (
                thisOpportunity.StageName == STAGENAME_OFFER_APPROVED &&
                oldOpportunity.StageName != STAGENAME_CONTRACT_PENDING &&
                thisOpportunity.Purchase_Agreement_Sent_Out_Date__c != null
            ) {
                thisOpportunity.StageName = STAGENAME_CONTRACT_PENDING;
            }

            if (
                (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                thisOpportunity.StageName == STAGENAME_ESCROW) &&
                oldOpportunity.StageName != STAGENAME_CANCELLATION_SUBMITTED &&
                thisOpportunity.Cancel_Approval_Status__c == CANCELAPPROVALSTATUS_PENDING
            ) {
                thisOpportunity.StageName = STAGENAME_CANCELLATION_SUBMITTED;
            }
            if (
                (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                thisOpportunity.StageName == STAGENAME_ESCROW ||
                thisOpportunity.StageName == STAGENAME_CANCELLATION_SUBMITTED) &&
                oldOpportunity.StageName != STAGENAME_CANCELLATION_APPROVED &&
                thisOpportunity.Cancel_Approval_Status__c == CANCELAPPROVALSTATUS_APPROVED
            ) {
                thisOpportunity.StageName = STAGENAME_CANCELLATION_APPROVED;
            }

            if (
                thisOpportunity.Cancellation_Document_Sent_out_Date__c != null &&
                oldOpportunity.StageName != STAGENAME_PENDING_CANCELLATION &&
                thisOpportunity.Canceled_Date__c == null
            ) {
                if (
                    thisOpportunity.Opt_In_Cancellation_Approval__c == true &&
                    thisOpportunity.Cancel_Approval_Status__c == CANCELAPPROVALSTATUS_APPROVED
                ) {
                    thisOpportunity.StageName = STAGENAME_PENDING_CANCELLATION;
                } else if (
                    thisOpportunity.Opt_In_Cancellation_Approval__c == false &&
                    thisOpportunity.Cancel_Approval_Status__c != CANCELAPPROVALSTATUS_SAVED
                ) {
                    thisOpportunity.StageName = STAGENAME_PENDING_CANCELLATION;
                }
            }

            if (
                (thisOpportunity.Buyer_Unavailable_to_Sign_Cancellation__c == true ||
                thisOpportunity.Buyer_Signed_Cancellation_Document_Date__c != null) &&
                thisOpportunity.Canceled_Date__c == null &&
                thisOpportunity.Finalize_Cancellation_Release_Home_Site__c == null
            ) {
                if (
                    thisOpportunity.Opt_In_Cancellation_Approval__c == true &&
                    thisOpportunity.Cancel_Approval_Status__c == CANCELAPPROVALSTATUS_APPROVED
                ) {
                    thisOpportunity.Canceled_Date__c = System.today();
                    thisOpportunity.StageName = STAGENAME_CANCELLED;
                } else if (thisOpportunity.Opt_In_Cancellation_Approval__c == false) {
                    thisOpportunity.Canceled_Date__c = System.today();
                    thisOpportunity.StageName = STAGENAME_CANCELLED;
                }
            }

            if (
                oldOpportunity.StageName != STAGENAME_APPROVED_TO_RESELL &&
                thisOpportunity.Cancel_Approval_Status__c == CANCELAPPROVALSTATUS_APPROVED &&
                thisOpportunity.Finalize_Cancellation_Release_Home_Site__c != null
            ) {
                thisOpportunity.StageName = STAGENAME_APPROVED_TO_RESELL;
            }

            if (listStatusesForCancelledRecordType.contains(thisOpportunity.StageName)) {
                thisOpportunity.RecordTypeId = MAP_OPPORTUNITY_RECORDTYPE_BY_DEVELOPERNAME.get(RECORDTYPE_CANCELLED)
                    .getRecordTypeId();
            }

            if (
                listNewCancelApprovalStatus.contains(thisOpportunity.Cancel_Approval_Status__c) &&
                listOldCancelApprovalStatus.contains(oldOpportunity.Cancel_Approval_Status__c) &&
                thisOpportunity.Purchase_Agreement_Buyer_Signed_Date__c != null &&
                (thisOpportunity.StageName == STAGENAME_CANCELLATION_SUBMITTED ||
                thisOpportunity.StageName == STAGENAME_CANCELLATION_APPROVED ||
                thisOpportunity.StageName == STAGENAME_PENDING_CANCELLATION)
            ) {
                if (thisOpportunity.Purchase_Agreement_VP_Signed_Date__c == null) {
                    thisOpportunity.StageName = STAGENAME_CONTRACTED;
                    thisOpportunity.recordTypeId = MAP_OPPORTUNITY_RECORDTYPE_BY_DEVELOPERNAME.get(RECORDTYPE_OPEN)
                        .getRecordTypeId();
                } else if (thisOpportunity.Purchase_Agreement_VP_Signed_Date__c != null) {
                    thisOpportunity.StageName = STAGENAME_ESCROW;
                    thisOpportunity.recordTypeId = MAP_OPPORTUNITY_RECORDTYPE_BY_DEVELOPERNAME.get(RECORDTYPE_ESCROW)
                        .getRecordTypeId();
                }
            }

            if (
                thisOpportunity.Purchase_Agreement_Buyer_Signed_Date__c != null &&
                thisOpportunity.Sales_Reported_Date__c != null &&
                thisOpportunity.Canceled_Date__c == null &&
                thisOpportunity.Sales_Ratified_Date__c == null &&
                thisOpportunity.StageName == STAGENAME_CONTRACT_PENDING &&
                oldOpportunity.StageName != STAGENAME_CONTRACTED &&
                thisOpportunity.Earnest_Deposit_Received_Met_Deposit_Min__c
            ) {
                thisOpportunity.StageName = STAGENAME_CONTRACTED;
            }
        }
    }

    /**
     * @description Method Used in the After Trigger context to evaluate and update the related Quote Lines
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunties      Trigger.oldMap
     * @param   mapQuoteLinesGroupedByQuote     Map Quote Lines grouped by Quote
     * @return  List of Quote Lines to UPdate
     */
    public static List<SBQQ__QuoteLine__c> evaluateAndUpdateQuoteLines(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, List<SBQQ__QuoteLine__c>> mapQuoteLinesGroupedByQuote
    ) {
        Set<Id> setPrimaryQuoteIds = new Set<Id>();
        List<SBQQ__QuoteLine__c> listQuoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            if (
                thisOpportunity.StageName == STAGENAME_ESCROW &&
                oldOpportunity.StageName != STAGENAME_ESCROW &&
                mapQuoteLinesGroupedByQuote.containsKey(thisOpportunity.SBQQ__PrimaryQuote__c)
            ) {
                setPrimaryQuoteIds.add(thisOpportunity.SBQQ__PrimaryQuote__c);
            }
        }
        for (Id primaryQuoteId : setPrimaryQuoteIds) {
            for (SBQQ__QuoteLine__c thisQuoteLine : mapQuoteLinesGroupedByQuote.get(primaryQuoteId)) {
                if (thisQuoteLine.Product_Type__c == 'Incentive' && !thisQuoteLine.SBQQ__PriceEditable__c) {
                    thisQuoteLine.SBQQ__PriceEditable__c = true;
                    listQuoteLinesToUpdate.add(thisQuoteLine);
                }
            }
        }

        return listQuoteLinesToUpdate;
    }

    /**
     * @description Method to evaluate the Contact Names on the Opportunity and set the Contact Status
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapContactsToUpdate     Map of Contacts By Id to Update
     * @param   mapContactsById         Map of Contacts by Ids retrieved from the getAllContacts method
     * @return Map of ContactByIds that will be updated
     */
    public static Map<Id, Contact> evaluateContactStatusToNHAQualified(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunities,
        Map<Id, Contact> mapContactsToUpdate,
        Map<Id, Contact> mapContactsById
    ) {
        String NHAProfileIds = System.Label.NHAProfilesIds;
        String opportunityStages = System.Label.Opportunity_Stages;
        List<Contact> contactStatusChanged = new List<Contact>();
        Set<Id> setContactNameIds = new Set<Id>();
        for (Opportunity opp : listNewOpportunities) {
            if (
                NHAProfileIds.Contains(UserInfo.getProfileId()) &&
                opportunityStages.contains(opp.StageName) &&
                opp.Contact_Name__c != null
            ) {
                setContactNameIds.add(opp.Contact_Name__c);
            }
        }
        for (Id thisContactNameId : setContactNameIds) {
            Contact thisContact = mapContactsById.get(thisContactNameId);
            if (thisContact.Contact_Status__c != 'NHA Qualified') {
                if (!mapContactsToUpdate.containsKey(thisContact.Id)) {
                    mapContactsToUpdate.put(thisContact.Id, thisContact);
                }
                Contact contactToUpdate = mapContactsToUpdate.get(thisContact.Id);
                contactToUpdate.Contact_Status__c = 'NHA Qualified';
                contactToUpdate.OwnerId = UserInfo.getUserId();
            }
        }
        return mapContactsToUpdate;
    }

    /**
     * @description Overload Method to invoke during the before Insert context
     * @param   listNewOpportunities    Trigger.New
     * @param   mapCommunitySitesById   Map of Community Sites By Ids retrieved from the getCommunitySites method
     */
    public static void setFieldsFromCommunitySite(
        List<Opportunity> listNewOpportunities,
        Map<Id, Community_Site__c> mapCommunitySitesById
    ) {
        Map<Id, SBQQ__Quote__c> mapQuoteByIds = new Map<Id, SBQQ__Quote__c>();
        Map<Id, Opportunity> mapOldOpportunties = new  Map<Id, Opportunity>();
        setFieldsFromCommunitySite(listNewOpportunities, mapOldOpportunties, mapCommunitySitesById, mapQuoteByIds);
    }

    /**
     * @description Method to evaluate and set the Amount Field
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapCommunitySitesById   Map of Community Sites By Ids retrieved from the getCommunitySites method
     * @param   mapQuotesById           Map of Quote by Ids retrieved from the getQuotes method
     */
    public static void setFieldsFromCommunitySite(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, Community_Site__c> mapCommunitySitesById,
        Map<Id, SBQQ__Quote__c> mapQuotesById
    ) {
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Community_Site__c thisCommunitySite = mapCommunitySitesById.get(thisOpportunity.Community_Site__c);
            Opportunity oldOpportunity = mapOldOpportunties?.get(thisOpportunity.Id);
            if (
                thisCommunitySite?.Average_Sales_Price__c != null &&
                thisCommunitySite?.Active__c == true &&
                thisCommunitySite?.Phase_2_Division__c == true &&
                (thisOpportunity.amount == null ||
                thisOpportunity.amount == 0.00)
            ) {
                SBQQ__Quote__c thisQuote = mapQuotesById.get(thisOpportunity.SBQQ__PrimaryQuote__c);
                if (
                    thisOpportunity.SBQQ__PrimaryQuote__c == null ||
                    (thisQuote?.SBQQ__Primary__c == true &&
                    thisQuote?.Total_Final_Purchase_Price__c == 0.00)
                ) {
                    thisOpportunity.amount = thisCommunitySite?.Average_Sales_Price__c;
                }
            }
            System.debug('### thisCommunitySite '+thisCommunitySite);
            if (//thisOpportunity.Community_Site__c != oldOpportunity?.Community_Site__c &&
                thisOpportunity.Community_Site__c != null 
            ) {
               System.debug(Opportunity.SobjectType.Additional_Terms_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Anne_Arundel_County_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Buyer_is_ordering_options__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Conditional_Public_Report_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Condominium_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Deposit_Disclosure__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Design_Studio__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Designer__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Escrow_Company__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Escrow_Representative__c.getDescribe().isUpdateable());

               System.debug(Opportunity.SobjectType.Frederick_County_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.General_Disclosure_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.General_Escrow_Instructions_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Homeowners_Association_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Incentive_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Independent_Inspectors_Policy_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Mineral_and_Oil_and_Gas_Rights_Mandatory__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Model_Home_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Montgomery_County_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Montgomery_County_Disclosure_of_Property__c.getDescribe().isUpdateable());

               System.debug(Opportunity.SobjectType.New_Home_Warranty_Plan_Disclosure__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Occupancy_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Options_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Options_to_be_Added__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Other_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Post_Closing_Dispute_Resolution_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Solar_Energy_System_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Statute_of_Limitations_Addendum__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Title_Company_Name__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Title_Company_Representative__c.getDescribe().isUpdateable());
                
               System.debug(Opportunity.SobjectType.Water_and_Sewer_Charges_Addendum__c.getDescribe().isUpdateable());

               System.debug(Opportunity.SobjectType.Approver__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Construction_Admin__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Director_of_Sales__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Discount_Approver_2__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Discount_Approver_3__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Discount_Approver_4__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Division_President__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Escrow_Coordinator__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.NHS__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.Purchasing_Admin__c.getDescribe().isUpdateable());

               System.debug(Opportunity.SobjectType.TRI_Pointe_Connect__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.VP_of_Construction__c.getDescribe().isUpdateable());
               System.debug(Opportunity.SobjectType.VP_of_Sales__c.getDescribe().isUpdateable());

               System.debug('after updatabel');
                System.debug( thisCommunitySite?.Additional_Terms_Addendum__c);
                System.debug( thisCommunitySite?.Anne_Arundel_County_Addendum__c);
                System.debug( thisCommunitySite?.Buyer_is_ordering_options__c);
                System.debug( thisCommunitySite?.Conditional_Public_Report_Addendum__c);
                System.debug( thisCommunitySite?.Condominium_Addendum__c);
                System.debug( thisCommunitySite?.Deposit_Disclosure__c);
                System.debug( thisCommunitySite?.Design_Studio__c);
                System.debug( thisCommunitySite?.Designer__c);
                System.debug( thisCommunitySite?.Escrow_Company__c);
                System.debug( thisCommunitySite?.Closing_Agent_Representative__c);

                System.debug( thisCommunitySite?.Frederick_County_Addendum__c);
                System.debug( thisCommunitySite?.General_Disclosure_Addendum__c);
                System.debug( thisCommunitySite?.General_Escrow_Instructions_Addendum__c);
                System.debug( thisCommunitySite?.Homeowners_Association_Addendum__c);
                System.debug( thisCommunitySite?.Incentive_Addendum__c);
                System.debug( thisCommunitySite?.Independent_Inspectors_Policy_Addendum__c);
                System.debug( thisCommunitySite?.Mineral_and_Oil_and_Gas_Rights_Mandatory__c);
                System.debug( thisCommunitySite?.Model_Home_Addendum__c);
                System.debug( thisCommunitySite?.Montgomery_County_Addendum__c);
                System.debug( thisCommunitySite?.Montgomery_County_Disclosure_of_Property__c);

                System.debug( thisCommunitySite?.New_Home_Warranty_Plan_Disclosure__c);
                System.debug( thisCommunitySite?.Occupancy_Addendum__c);
                System.debug( thisCommunitySite?.Options_Addendum__c);
                System.debug( thisCommunitySite?.Options_to_be_Added__c);
                System.debug( thisCommunitySite?.Other_Addendum__c);
                System.debug( thisCommunitySite?.Post_Closing_Dispute_Resolution_Addendum__c);
                System.debug( thisCommunitySite?.Solar_Energy_System_Addendum__c);
                System.debug( thisCommunitySite?.Statute_of_Limitations_Addendum__c);
                System.debug( thisCommunitySite?.Title_Company_Name__c);
                System.debug( thisCommunitySite?.Title_Company_Representative__c);
                
                System.debug( thisCommunitySite?.Water_and_Sewer_Charges_Addendum__c);

                System.debug( thisCommunitySite?.Approver__c);
                System.debug( thisCommunitySite?.Construction_Admin__c);
                System.debug( thisCommunitySite?.Director_of_Sales__c);
                System.debug( thisCommunitySite?.Approver_2__c);
                System.debug( thisCommunitySite?.Approver_3__c);
                System.debug( thisCommunitySite?.Approver_4__c);
                System.debug( thisCommunitySite?.Division_President__c);
                System.debug( thisCommunitySite?.Escrow_Coordinator__c);
                System.debug( thisCommunitySite?.NHS__c);
                System.debug( thisCommunitySite?.Purchasing_Admin__c);

                System.debug( thisCommunitySite?.TRI_Pointe_Connect__c);
                System.debug( thisCommunitySite?.VP_of_Construction__c);
                System.debug( thisCommunitySite?.VP_of_Sales__c);
                // end debugs
                
                thisOpportunity.Additional_Terms_Addendum__c = thisCommunitySite?.Additional_Terms_Addendum__c;
                thisOpportunity.Anne_Arundel_County_Addendum__c = thisCommunitySite?.Anne_Arundel_County_Addendum__c;
                thisOpportunity.Buyer_is_ordering_options__c = thisCommunitySite?.Buyer_is_ordering_options__c;
                thisOpportunity.Conditional_Public_Report_Addendum__c = thisCommunitySite?.Conditional_Public_Report_Addendum__c;
                thisOpportunity.Condominium_Addendum__c = thisCommunitySite?.Condominium_Addendum__c;
                thisOpportunity.Deposit_Disclosure__c = thisCommunitySite?.Deposit_Disclosure__c;
                thisOpportunity.Design_Studio__c = thisCommunitySite?.Design_Studio__c;
                thisOpportunity.Designer__c = thisCommunitySite?.Designer__c;
                thisOpportunity.Escrow_Company__c = thisCommunitySite?.Escrow_Company__c;
                thisOpportunity.Escrow_Representative__c = thisCommunitySite?.Closing_Agent_Representative__c;

                thisOpportunity.Frederick_County_Addendum__c = thisCommunitySite?.Frederick_County_Addendum__c;
                thisOpportunity.General_Disclosure_Addendum__c = thisCommunitySite?.General_Disclosure_Addendum__c;
                thisOpportunity.General_Escrow_Instructions_Addendum__c = thisCommunitySite?.General_Escrow_Instructions_Addendum__c;
                thisOpportunity.Homeowners_Association_Addendum__c = thisCommunitySite?.Homeowners_Association_Addendum__c;
                thisOpportunity.Incentive_Addendum__c = thisCommunitySite?.Incentive_Addendum__c;
                thisOpportunity.Independent_Inspectors_Policy_Addendum__c = thisCommunitySite?.Independent_Inspectors_Policy_Addendum__c;
                thisOpportunity.Mineral_and_Oil_and_Gas_Rights_Mandatory__c = thisCommunitySite?.Mineral_and_Oil_and_Gas_Rights_Mandatory__c;
                thisOpportunity.Model_Home_Addendum__c = thisCommunitySite?.Model_Home_Addendum__c;
                thisOpportunity.Montgomery_County_Addendum__c = thisCommunitySite?.Montgomery_County_Addendum__c;
                thisOpportunity.Montgomery_County_Disclosure_of_Property__c = thisCommunitySite?.Montgomery_County_Disclosure_of_Property__c;

                thisOpportunity.New_Home_Warranty_Plan_Disclosure__c = thisCommunitySite?.New_Home_Warranty_Plan_Disclosure__c;
                thisOpportunity.Occupancy_Addendum__c = thisCommunitySite?.Occupancy_Addendum__c;
                thisOpportunity.Options_Addendum__c = thisCommunitySite?.Options_Addendum__c;
                thisOpportunity.Options_to_be_Added__c = thisCommunitySite?.Options_to_be_Added__c;
                thisOpportunity.Other_Addendum__c = thisCommunitySite?.Other_Addendum__c;
                thisOpportunity.Post_Closing_Dispute_Resolution_Addendum__c = thisCommunitySite?.Post_Closing_Dispute_Resolution_Addendum__c;
                thisOpportunity.Solar_Energy_System_Addendum__c = thisCommunitySite?.Solar_Energy_System_Addendum__c;
                thisOpportunity.Statute_of_Limitations_Addendum__c = thisCommunitySite?.Statute_of_Limitations_Addendum__c;
                thisOpportunity.Title_Company_Name__c = thisCommunitySite?.Title_Company_Name__c;
                thisOpportunity.Title_Company_Representative__c = thisCommunitySite?.Title_Company_Representative__c;
                
                thisOpportunity.Water_and_Sewer_Charges_Addendum__c = thisCommunitySite?.Water_and_Sewer_Charges_Addendum__c;

                thisOpportunity.Approver__c = thisCommunitySite?.Approver__c;
                thisOpportunity.Construction_Admin__c = thisCommunitySite?.Construction_Admin__c;
                thisOpportunity.Director_of_Sales__c = thisCommunitySite?.Director_of_Sales__c;
                thisOpportunity.Discount_Approver_2__c = thisCommunitySite?.Approver_2__c;
                thisOpportunity.Discount_Approver_3__c = thisCommunitySite?.Approver_3__c;
                thisOpportunity.Discount_Approver_4__c = thisCommunitySite?.Approver_4__c;
                thisOpportunity.Division_President__c = thisCommunitySite?.Division_President__c;
                thisOpportunity.Escrow_Coordinator__c = thisCommunitySite?.Escrow_Coordinator__c;
                thisOpportunity.NHS__c = thisCommunitySite?.NHS__c;
                thisOpportunity.Purchasing_Admin__c = thisCommunitySite?.Purchasing_Admin__c;

                thisOpportunity.TRI_Pointe_Connect__c = thisCommunitySite?.TRI_Pointe_Connect__c;
                thisOpportunity.VP_of_Construction__c = thisCommunitySite?.VP_of_Construction__c;
                thisOpportunity.VP_of_Sales__c = thisCommunitySite?.VP_of_Sales__c;
            }

            if( thisOpportunity.Community_Site__c != null &&
                thisOpportunity.Escrow_Company__c == null &&
                thisOpportunity.Added_Escrow_Company__c == false
            ) {
                thisOpportunity.Escrow_Company__c = thisCommunitySite?.Escrow_Company__c;
                thisOpportunity.Added_Escrow_Company__c = true;
            }

        }
    }

    /**
     * @description Overload Method to be invoked in the beforeInsert context
     * @param   listNewOpportunities    Trigger.New
     * @param   mapContactById          Map of Contacts By Ids retrieved from the getContacts method
     */
    public static void setFieldsFromContacts(List<Opportunity> listNewOpportunities, Map<Id, Contact> mapContactById) {
        Map<Id, Opportunity> mapOldOpportunity = new Map<Id, Opportunity>();
        setFieldsFromContacts(listNewOpportunities, mapOldOpportunity, mapContactById);
    }

    /**
     * @description Method to evaluate and set the Amount Field
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapContactById          Map of Contacts By Ids retrieved from the getContacts method
     */
    public static void setFieldsFromContacts(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, Contact> mapContactById
    ) {
        List<String> listStageNamesToExclude = new List<String>{
            STAGENAME_CONTRACTED,
            STAGENAME_ESCROW,
            STAGENAME_PENDING_CANCELLATION,
            STAGENAME_CANCELLED,
            STAGENAME_CLOSED_LOST,
            STAGENAME_CLOSED_WON,
            STAGENAME_CANCELLATION_SUBMITTED,
            STAGENAME_CANCELLATION_APPROVED,
            STAGENAME_APPROVED_TO_RESELL
        };
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            if (
                thisOpportunity.Escrow_Coordinator__c != null &&
                thisOpportunity.Escrow_Coordinator__c != oldOpportunity?.Escrow_Coordinator__c
            ) {
                Contact escrowContact = mapContactById.get(thisOpportunity.Escrow_Coordinator__c);
                thisOpportunity.Escrow_Internal_Name__c = escrowContact?.Name;
                thisOpportunity.Escrow_Internal_Email__c = escrowContact?.Email;
            }

            if (
                thisOpportunity.Contact_Name__c != oldOpportunity?.Contact_Name__c &&
                !listStageNamesToExclude.contains(thisOpportunity.StageName)
            ) {
                Contact contactNameContact = mapContactById.get(thisOpportunity.Contact_Name__c);
                if (
                    contactNameContact?.MailingCountry == 'United States' ||
                    contactNameContact?.MailingCountry == null
                ) {
                    thisOpportunity.Foreign_National__c = 'No';
                } else {
                    thisOpportunity.Foreign_National__c = 'Yes';
                }
            }
        }
    }

    /**
     * @description Method to set fields on the opportunity derived from Opportunity Contact records
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapOpportunityContactRolesByOpportunityId   Reference Map of Opportunity Contact roles keyed by the Opportunity Id
     */
    public static void setFieldsFromOpportunityContactRoles(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, List<OpportunityContactRole>> mapOpportunityContactRolesByOpportunityId
    ) {
        for (Opportunity thisOpportunity : listNewOpportunities) {
            thisOpportunity.PB_Name__c = '';
            thisOpportunity.PB_Email__c = '';
            thisOpportunity.CB1_Name__c = '';
            thisOpportunity.CB1_Email__c = '';
            thisOpportunity.CB2_Name__c = '';
            thisOpportunity.CB2_Email__c = '';
            thisOpportunity.CB3_Name__c = '';
            thisOpportunity.CB3_Email__c = '';

            List<OpportunityContactRole> listOpportunityContactRole = mapOpportunityContactRolesByOpportunityId.get(
                thisOpportunity?.Id
            );
            if (listOpportunityContactRole != null && !listOpportunityContactRole?.isEmpty()) {
                for (OpportunityContactRole thisOpportunityContactRole : listOpportunityContactRole) {
                    switch on (thisOpportunityContactRole.Role) {
                        when 'Buyer' {
                            thisOpportunity.PB_Name__c = thisOpportunityContactRole.Contact?.Name;
                            thisOpportunity.PB_Email__c = thisOpportunityContactRole.Contact?.Email;
                        }
                        when 'Co-Buyer 1' {
                            thisOpportunity.CB1_Name__c = thisOpportunityContactRole.Contact?.Name;
                            thisOpportunity.CB1_Email__c = thisOpportunityContactRole.Contact?.Email;
                        }
                        when 'Co-Buyer 2' {
                            thisOpportunity.CB2_Name__c = thisOpportunityContactRole.Contact?.Name;
                            thisOpportunity.CB2_Email__c = thisOpportunityContactRole.Contact?.Email;
                        }
                        when 'Co-Buyer 3' {
                            thisOpportunity.CB3_Name__c = thisOpportunityContactRole.Contact?.Name;
                            thisOpportunity.CB3_Email__c = thisOpportunityContactRole.Contact?.Email;
                        }
                    }
                }
            }
        }
    }

    /**
     * @description Method to set Broker fields on the opportunity derived from the Site Visit records
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapSiteVisitsByAccountId   Reference Map of Opportunity Contact roles keyed by the Opportunity Id
     */
    public static void setBrokersFromSiteVisit(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, List<Site_Visit__c>> mapSiteVisitsByAccountId
    ) {
        Boolean runningAsSystemAdmin = System.Label.DisableBrokerFunctionalityViaTrigger_ProfileNames.contains(
            UserInfo.getProfileId()
        );

        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);

            if (
                runningAsSystemAdmin &&
                (thisOpportunity.Broker_at_first_visit_Original__c !=
                oldOpportunity?.Broker_at_first_visit_Original__c ||
                thisOpportunity.Broker_at_first_visit__c != oldOpportunity?.Broker_at_first_visit__c)
            ) {
                continue;
            }

            if (mapSiteVisitsByAccountId.containsKey(thisOpportunity.AccountId)) {
                if (thisOpportunity.Do_Not_Allow_Broker_After_First_Visit__c && !thisOpportunity.Broker_Set__c) {
                    List<Site_Visit__c> listSiteVisits = mapSiteVisitsByAccountId.get(thisOpportunity.AccountId);
                    for (Site_Visit__c thisSiteVisit : listSiteVisits) {
                        if (
                            thisSiteVisit.Community_Site__c == thisOpportunity.Community_Site__c &&
                            thisSiteVisit.First_Visit_With_Agent__c
                        ) {
                            thisOpportunity.Broker_at_first_visit__c = 'Yes';
                            thisOpportunity.Broker_at_first_visit_Original__c = 'Yes';
                            thisOpportunity.Broker_s_Name__c = thisSiteVisit.Agent_Account__c;
                            thisOpportunity.Broker_Set__c = true;
                            break;
                        } else {
                            if (thisOpportunity.Broker_at_first_visit__c != 'Yes') {
                                thisOpportunity.Broker_at_first_visit__c = 'No';
                            }
                            if (thisOpportunity.Broker_at_first_visit_Original__c != 'Yes') {
                                thisOpportunity.Broker_at_first_visit_Original__c = 'No';
                            }
                        }
                    }
                } else if (!thisOpportunity.Do_Not_Allow_Broker_After_First_Visit__c) {
                    if (thisOpportunity.Broker_at_first_visit__c != 'Yes') {
                        thisOpportunity.Broker_at_first_visit__c = 'No';
                    }
                    if (thisOpportunity.Broker_at_first_visit_Original__c != 'Yes') {
                        thisOpportunity.Broker_at_first_visit_Original__c = 'No';
                    }
                }
            }
        }
    }

    /**
     * @description Method to validate Lender Account and Loan Processor's Account
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapContactById          Map Contacts keyed by Id from fetchContacts
     */
    public static void validateLoanProcessor(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, Contact> mapContactById
    ) {
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            Contact loanProcessorContact = mapContactById.get(thisOpportunity.LoanProcessor__c);
            if (loanProcessorContact == null) { continue; }

            if (thisOpportunity.Lender_Account__c != oldOpportunity.Lender_Account__c) {
                if (thisOpportunity.Lender_Account__c == null) {
                    thisOpportunity.LoanProcessor__c = null;
                } else if (thisOpportunity.Lender_Account__c != loanProcessorContact?.AccountId) {
                    thisOpportunity.addError('Please select Lender Account related to Loan Processor.');
                }
            }
            if (thisOpportunity.Lender_Account__c != oldOpportunity.Lender_Account__c) {
                if (
                    thisOpportunity.Lender_Account__c != null &&
                    thisOpportunity.Lender_Account__c != loanProcessorContact?.AccountId
                ) {
                    thisOpportunity.addError('Please select Loan Processor contact related to Lender Account.');
                }
            }

            if (thisOpportunity.Lender_Account__c == null && thisOpportunity.LoanProcessor__c != null) {
                thisOpportunity.addError('Please select a Lender Account.');
            }
        }
    }

    /**
     * @description Method to set fields on the opportunity derived from Quote Records
     * @param   listNewOpportunities    Trigger.New
     * @param   mapQuoteById            Reference Map of Quote by Ids
     */
    public static void setFieldsFromPrimaryQuote(
        List<Opportunity> listNewOpportunities,
        Map<Id, SBQQ__Quote__c> mapQuoteById
    ) {
        for (Opportunity thisOpportunity : listNewOpportunities) {
            SBQQ__Quote__c primaryQuote = mapQuoteById.get(thisOpportunity.SBQQ__PrimaryQuote__c);
            if (primaryQuote != null) {
                thisOpportunity.Home_Site_Lookup__c = primaryQuote.Home_Site_Lookup__c;
                thisOpportunity.Floor_Plan_Lookup__c = primaryQuote.Floor_Plan_Lookup__c;
                thisOpportunity.Phase_Lookup__c = primaryQuote.Phase_Lookup__c;
            }
        }
    }

    /**
     * @description Method to set the IsTPCResponseSent field to false if the integration field has changed
     *              and Meets either the StageName conditions or the Canceled date has changed
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapContactById          Map Contacts keyed by Id from fetchContacts
     */
    public static void setTPCResponseField(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties
    ) {
        List<Schema.FieldSetMember> listIntegrationFields = SObjectType.Opportunity.fieldSets.TPC_Integration_Fields.getFields();
        List<String> listStageNames = new List<String>{
            STAGENAME_CONTRACTED,
            STAGENAME_ESCROW,
            STAGENAME_CANCELLATION_SUBMITTED,
            STAGENAME_CANCELLATION_APPROVED,
            STAGENAME_PENDING_CANCELLATION
        };
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            Boolean isIntegrationFieldChange = false;
            for (Schema.FieldSetMember thisFieldSetMember : listIntegrationFields) {
                String thisFieldPath = thisFieldSetMember.getFieldPath();
                if (thisOpportunity.get(thisFieldPath) != oldOpportunity.get(thisFieldPath)) {
                    isIntegrationFieldChange = true;
                    break;
                }
            }

            if (
                thisOpportunity.IsTPCResponseSent__c == true &&
                isIntegrationFieldChange == true &&
                (listStageNames.contains(thisOpportunity.StageName) ||
                (thisOpportunity.StageName == STAGENAME_CLOSED_WON &&
                oldOpportunity.StageName != STAGENAME_CLOSED_WON) ||
                (thisOpportunity.Canceled_Date__c != null &&
                oldOpportunity.Canceled_Date__c == null))
            ) {
                thisOpportunity.IsTPCResponseSent__c = false;
            }
        }
    }

    /**
     * @description Method to set the Affiliated Title Company Boolean field from the related Titile Company
     * @param   listNewOpportunities    Trigger.New
     * @param   mapOldOpportunities     Trigger.oldMap
     * @param   mapAccountByIds         mapAccountByIds
     */
    public static void setAffiliatedTitleCompany(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, Account> mapAccountByIds
    ) {
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            Account titleCompanyAccount = mapAccountByIds.get(thisOpportunity.Title_Company_Name__c);

            if (thisOpportunity.Title_Company_Name__c != oldOpportunity.Title_Company_Name__c) {
                thisOpportunity.Affiliated_Title_Company__c = (titleCompanyAccount?.Affiliated__c != null)
                    ? titleCompanyAccount.Affiliated__c
                    : false;
            }
        }
    }

    /**
     * @description Method to Docu Sign Status when Cancel Approval Status is updated to Saved
     * @param   listNewOpportunities                  Trigger.New
     * @param   mapDocuSignStatuesByOpportunityId     Reference Map of DocuSign Statuses keyed by Opportunity Id
     */
    public static void validateDocuSignStatuses(
        List<Opportunity> listNewOpportunties,
        Map<Id, List<dsfs__DocuSign_Status__c>> mapDocuSignStatuesByOpportunityId
    ) {
        for (Opportunity thisOpportunity : listNewOpportunties) {
            if (mapDocuSignStatuesByOpportunityId.containsKey(thisOpportunity.Id)) {
                List<dsfs__DocuSign_Status__c> listDocuSignStatus = mapDocuSignStatuesByOpportunityId.get(
                    thisOpportunity.Id
                );
                for (dsfs__DocuSign_Status__c thisDocuSignStatus : listDocuSignStatus) {
                    if (
                        thisDocuSignStatus.Document_Type__c == 'Cancellation' &&
                        thisDocuSignStatus.dsfs__Envelope_Status__c == 'Sent'
                    ) {
                        thisOpportunity.addError(
                            'Before selecting Cancel Approval Status as Saved, you first need to void the envelope.'
                        );
                    }
                }
            }
        }
    }

    /**
     * @description Method to generate a List of Opportunity Team Members from Nha Assi
     * @param   listNewOpportunities         Trigger.New
     * @param   mapNhaUsersByCommunityId     Reference Map of Nha User Ids By Community Site Id
     * @return  List of Opportunity Team members for Insert
     */
    public static List<OpportunityTeamMember> generateOpportunityTeamMembers(
        List<Opportunity> listNewOpportunities,
        Map<Id, Set<Id>> mapNhaUsersByCommunityId
    ) {
        List<OpportunityTeamMember> listOpportunityTeamMember = new List<OpportunityTeamMember>();
        for (Opportunity thisOpportunity : listNewOpportunities) {
            Set<Id> setNhaUserIds = mapNhaUsersByCommunityId.get(thisOpportunity.Community_Site__c);
            if (setNhaUserIds != null) {
                for (Id thisNhaUserId : setNhaUserIds) {
                    if (thisOpportunity.OwnerId != thisNhaUserId) {
                        listOpportunityTeamMember.add(
                            new OpportunityTeamMember(
                                UserId = thisNhaUserId,
                                OpportunityId = thisOpportunity.Id,
                                TeamMemberRole = 'NHA'
                            )
                        );
                    }
                }
            }
        }
        return listOpportunityTeamMember;
    }

    /**
     * @description Method to generate a List of Opportunity Contact Roles and Assigning the Roles
     * @param   listNewOpportunities                            Trigger.New
     * @param   mapContactsByAccountId                          Reference Map of Contacts Group By Account Id
     * @param   mapOpportunityContactRolesByOpportunityId       Reference Map of Opportunity Contact Roles Group By Opportunity Id
     * @return  List of Opportunity Contact Roles for Insert
     */
    public static List<OpportunityContactRole> generateOpportunityContactRole(
        List<Opportunity> listNewOpportunity,
        Map<Id, List<Contact>> mapContactsByAccountId,
        Map<Id, List<OpportunityContactRole>> mapOpportunityContactRolesByOpportunityId
    ) {
        List<OpportunityContactRole> listOpportunityContactRoleForInsert = new List<OpportunityContactRole>();
        for (Opportunity thisOpportunity : listNewOpportunity) {
            if (thisOpportunity.Contact_Name__c == null)
                continue;

            List<Contact> listContacts = mapContactsByAccountId.get(thisOpportunity.AccountId);
            if (listContacts == null || listContacts.isEmpty())
                continue;

            Set<Id> setContactIdsOfExistingOpportunityContactRoles = new Set<Id>();
            List<OpportunityContactRole> listExistingOpportunityContactRoles = mapOpportunityContactRolesByOpportunityId.get(
                thisOpportunity.Id
            );
            if (listExistingOpportunityContactRoles != null) {
                for (OpportunityContactRole thisOpportunityContactRole : listExistingOpportunityContactRoles) {
                    setContactIdsOfExistingOpportunityContactRoles.add(thisOpportunityContactRole.contactId);
                }
            }

            Integer coBuyerCount = 0;
            for (Contact thisContact : listContacts) {
                if (setContactIdsOfExistingOpportunityContactRoles.contains(thisContact.Id))
                    continue;

                Boolean isPrimaryBuyer = false;
                String thisRole = thisContact.Account_Type__c;

                if (thisContact.Id == thisOpportunity.Contact_Name__c) {
                    isPrimaryBuyer = true;
                    thisRole = 'Buyer';
                } else if (thisContact.Account_Type__c == 'Co-Buyer' || thisContact.Account_Type__c == 'Buyer') {
                    switch on coBuyerCount {
                        when 0 {
                            thisRole = 'Co-Buyer 1';
                            coBuyerCount++;
                        }
                        when 1 {
                            thisRole = 'Co-Buyer 2';
                            coBuyerCount++;
                        }
                        when else {
                            thisRole = 'Co-Buyer 3';
                        }
                    }
                }

                listOpportunityContactRoleForInsert.add(
                    new OpportunityContactRole(
                        Role = thisRole,
                        OpportunityId = thisOpportunity.Id,
                        ContactId = thisContact.Id,
                        IsPrimary = isPrimaryBuyer
                    )
                );
            }
        }
        return listOpportunityContactRoleForInsert;
    }

    /**
     * @description Method to evaluate and set Opportunity Share records
     * @param   listOpportunityShare    List of Opportuntiy Share Records
     * @return   list of Opportunity Share records for update
     */
    public static List<OpportunityShare> evaluateOpportunityShareRecords(List<OpportunityShare> listOpportunityShare) {
        for (OpportunityShare thisOpportunityShare : listOpportunityShare) {
            thisOpportunityShare.OpportunityAccessLevel = 'Edit';
        }
        return listOpportunityShare;
    }

    /**
     * @description Method to clear the Reason fields on a list of Contacts
     * @param   mapContactsByAccountId      Reference Map of Contacts Group By Account Id
     * @return  List of Contacts for update
     */
    public static List<Contact> clearReasonFieldsOnContact(Map<Id, List<Contact>> mapContactsByAccountId) {
        List<Contact> listContactsForUpdate = new List<Contact>();
        List<Contact> listOfContactsToBeEvaluated = new List<Contact>();

        for (List<Contact> listContacts : mapContactsByAccountId.values()) {
            listOfContactsToBeEvaluated.addAll(listContacts);
        }

        for (Contact thisContact : listOfContactsToBeEvaluated) {
            Boolean addToList = false;
            if (thisContact.Closed_Lost_Reason__c != null) {
                thisContact.Closed_Lost_Reason_H__c = thisContact.Closed_Lost_Reason__c;
                thisContact.Closed_Lost_Reason__c = '';
                addToList = true;
            }
            if (thisContact.Revert_Reason__c != null) {
                thisContact.Revert_Reason__c = '';
                addToList = true;
            }
            if (thisContact.Disqualified_Reason__c != null) {
                thisContact.Disqualified_Reason__c = '';
                addToList = true;
            }
            if (addToList) {
                listContactsForUpdate.add(thisContact);
            }
        }
        return listContactsForUpdate;
    }

    /**
     * @description Method to Enqueue the queueable class NHSAppointmentOpp
     * @param setNhsAppointmentOpportunityIds   Set of Opportunity Ids
     * @param setNhsAppointmentAccountIds       Set of Account Ids
     * @param setCommunitySiteIds               Set of Community Site Ids
     * @param setContactIds                     Set of Contact Ids
     * @return  Id of the Enqueued Job
     */
    public static Id enqueueNhsAppointment(
        Set<Id> setNhsAppointmentOpportunityIds,
        Set<Id> setNhsAppointmentAccountIds,
        Set<Id> setCommunitySiteIds,
        Set<Id> setContactIds
    ) {
        Id jobID;
        if (
            Limits.getQueueableJobs() < Limits.getLimitQueueableJobs() &&
            !setNhsAppointmentOpportunityIds.isEmpty() &&
            !setNhsAppointmentAccountIds.isEmpty() &&
            !setCommunitySiteIds.isEmpty() &&
            !setContactIds.isEmpty()
        ) {
            jobID = System.enqueueJob(
                new NHSAppointmentOpp(
                    setNhsAppointmentOpportunityIds,
                    setContactIds,
                    setNhsAppointmentAccountIds,
                    setCommunitySiteIds
                )
            );
        }
        return jobId;
    }

    /**
     * @description Method to evaluate and set the Quotes Record Type Id
     * @param   mapQuotesToUpdate               Map of QuotesToUpdate
     * @param   mapOpportuntiiesToEvaluate      Map of Opportunties keyed by the Opportunity Id
     * @param   mapQuotesGroupByOpportunityId   Map of Quotes Grouped By Opportunity Id
     * @return   Map of Quotes to Update
     */
    public static Map<Id, SBQQ__Quote__c> evaluateQuotesRecordType(
        Map<Id, SBQQ__Quote__c> mapQuotesToUpdate,
        Map<Id, Opportunity> mapOpportuntiiesToEvaluate,
        Map<Id, List<SBQQ__Quote__c>> mapQuotesGroupByOpportunityId
    ) {
        List<SBQQ__Quote__c> listQuotesToUpdate = new List<SBQQ__Quote__c>();
        for (Opportunity thisOpportunity : mapOpportuntiiesToEvaluate.values()) {
            if (!mapQuotesGroupByOpportunityId.containsKey(thisOpportunity.Id)) {
                continue;
            }
            for (SBQQ__Quote__c thisQuote : mapQuotesGroupByOpportunityId.get(thisOpportunity.Id)) {
                Id quoteRecordTypeId;
                if (
                    thisOpportunity.StageName == STAGENAME_CONTRACT_PENDING ||
                    thisOpportunity.StageName == STAGENAME_CANCELLED
                ) {
                    quoteRecordTypeId = MAP_QUOTE_RECORDTYPE_BY_DEVELOPERNAME.get(
                            QUOTE_STAGENAME_CONTRACTPENDINGAPPROVED
                        )
                        .getRecordTypeId();
                }

                if (
                    thisQuote.SBQQ__Status__c == QUOTE_STATUS_APPROVED &&
                    (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                    thisOpportunity.StageName == STAGENAME_ESCROW ||
                    thisOpportunity.StageName == STAGENAME_OFFER_APPROVED)
                ) {
                    quoteRecordTypeId = MAP_QUOTE_RECORDTYPE_BY_DEVELOPERNAME.get(QUOTE_STAGENAME_APPROVED)
                        .getRecordTypeId();
                }

                if (
                    thisQuote.SBQQ__Status__c == QUOTE_STATUS_DRAFT &&
                    (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                    thisOpportunity.StageName == STAGENAME_ESCROW)
                ) {
                    quoteRecordTypeId = MAP_QUOTE_RECORDTYPE_BY_DEVELOPERNAME.get(QUOTE_STAGENAME_DRAFT)
                        .getRecordTypeId();
                }

                if (
                    thisOpportunity.StageName == STAGENAME_APPROVED_TO_RESELL ||
                    thisOpportunity.StageName == STAGENAME_CLOSED_WON ||
                    thisOpportunity.StageName == STAGENAME_CLOSED_LOST
                ) {
                    quoteRecordTypeId = MAP_QUOTE_RECORDTYPE_BY_DEVELOPERNAME.get(QUOTE_STAGENAME_CLOSED)
                        .getRecordTypeId();
                }

                if (quoteRecordTypeId != null && quoteRecordTypeId != thisQuote.RecordTypeId) {
                    if (!mapQuotesToUpdate.containsKey(thisQuote.Id)) {
                        mapQuotesToUpdate.put(thisQuote.Id, thisQuote);
                    }
                    SBQQ__Quote__c referencedQuote = mapQuotesToUpdate.get(thisQuote.Id);
                    referencedQuote.RecordTypeId = quoteRecordTypeId;
                }
            }
        }

        return mapQuotesToUpdate;
    }

    /**
     * @description Method to evaluate Price List Entries for Contracted or Closed Opportunties
     * @param   listOpportunitiesToEvaluate                    List of Opportunities
     * @param   mapPreClosingClosingMilestoneByOpportunityId   Map of Price List Entries By Community Site
     * @return  Map of Price List Entries to Update
     */
    public static Map<Id, Priority_List_Entry__c> evaluatePriceListEntry(
        List<Opportunity> listOpportunitiesToEvaluate,
        Map<Id, List<Priority_List_Entry__c>> mapPriorityListEntriesByCommunitySiteId
    ) {
        Map<Id, Priority_List_Entry__c> mapPriceListEntryToUpdate = new Map<Id, Priority_List_Entry__c>();
        for (Opportunity thisOpportunity : listOpportunitiesToEvaluate) {
            List<Priority_List_Entry__c> listPriorityListEntry = mapPriorityListEntriesByCommunitySiteId.get(
                thisOpportunity.Community_Site__c
            );
            if (listPriorityListEntry == null || listPriorityListEntry.isEmpty()) {
                continue;
            }
            for (Priority_List_Entry__c thisPriorityListEntry : listPriorityListEntry) {
                if (thisOpportunity.Contact_Name__c == thisPriorityListEntry.Buyer_Contact__c) {
                    thisPriorityListEntry.Status__c = 'Inactive';
                    thisPriorityListEntry.Inactive_Reason__c = thisOpportunity.StageName;
                    mapPriceListEntryToUpdate.put(thisPriorityListEntry.Id, thisPriorityListEntry);
                    break;
                }
            }
        }

        return mapPriceListEntryToUpdate;
    }

    /**
     * @description Method to Count and Aggregate Rollup Opportuntiteis for the Broker Account
     * @param   mapAccountsToUpdate                 Map of Accounts to Update keyed by its Id
     * @param   mapOpportunitiesGroupedByBrokerId   Map of Opportunties Group By the Broker Id
     * @return  Map of Price List Entries to Update
     */
    public static Map<Id, Account> evaluateBrokerRollup(
        Map<Id, Account> mapAccountsToUpdate,
        Map<Id, List<Opportunity>> mapOpportunitiesGroupedByBrokerId
    ) {
        for (Id brokerId : mapOpportunitiesGroupedByBrokerId.keyset()) {
            brokerRollupWrapper thisWrapper = new brokerRollupWrapper();
            for (Opportunity thisOpportunity : mapOpportunitiesGroupedByBrokerId.get(brokerId)) {
                thisWrapper.addOpportunity(thisOpportunity);
            }

            if (!mapAccountsToUpdate.containsKey(brokerId)) {
                mapAccountsToUpdate.put(brokerId, new Account(Id = brokerId));
            }
            Account thisAccount = mapAccountsToUpdate.get(brokerId);

            thisAccount.Opportunities__c = thisWrapper.opportunityCount;
            thisAccount.Value_Closed_Won_Opportunities__c = thisWrapper.closedWonTotal;
            thisAccount.Closed_Won_Opportunities__c = thisWrapper.closedWonCount;
            thisAccount.Open_Opportunities__c = thisWrapper.openCount;
            thisAccount.Value_Open_Opportunities__c = thisWrapper.openTotal;
        }
        return mapAccountsToUpdate;
    }

    /**
     * @description Method to Set the status field on the Task
     * @param   listTasks    List of Tasks
     * @return  List of tasks to Update
     */
    public static List<Task> completeAutoCreatedTasks(List<Task> listTasks) {
        for (Task thisTask : listTasks) {
            thisTask.Status = 'Completed';
            thisTask.Bypass_Date_Time__c = Datetime.now();
            thisTask.Auto_Completed__c = true;
        }
        return listTasks;
    }

    /**
     * @description Method to evaluate the Contacts when All Opportunties related to an Account
     * @param   mapContactsToUpdate                 Map of Contacts to update
     * @param   mapOpportunitiesToEvaluate           Map of Opportunties with Stage Name Changes
     * @param   mapContactsGroupedByAccountId       Map of Contacts group by Account Id
     * @param   mapAllOpportunitysGroupByAccount    Map of Opportuntites group by the Account Id
     * @return  return the Map of contacts to Update
     */
    public static Map<Id, Contact> evaluateContactsForChangedStageNames(
        Map<Id, Contact> mapContactsToUpdate,
        Map<Id, Opportunity> mapOpportunitiesToEvaluate,
        Map<Id, List<Contact>> mapContactsGroupedByAccountId,
        Map<Id, List<Opportunity>> mapAllOpportunitysGroupByAccount
    ) {
        for (Opportunity thisOpportunity : mapOpportunitiesToEvaluate.values()) {
            Id thisAccountId = thisOpportunity.AccountId;
            List<Contact> listContacts = mapContactsGroupedByAccountId.get(thisAccountId);

            if (thisOpportunity.StageName == STAGENAME_CLOSED_LOST) {
                Boolean isAllOtherClosedLost = isAllOtherOpportunityHasStage(
                    STAGENAME_CLOSED_LOST,
                    thisOpportunity,
                    mapAllOpportunitysGroupByAccount
                );
                mapContactsToUpdate = setContactForClosedLost(
                    mapContactsToUpdate,
                    thisOpportunity,
                    listContacts,
                    isAllOtherClosedLost
                );
            } else if (thisOpportunity.StageName == STAGENAME_CONTRACTED) {
                mapContactsToUpdate = setContactsFieldsForStage(
                    mapContactsToUpdate,
                    listContacts,
                    thisOpportunity.StageName
                );
            } else if (thisOpportunity.StageName == STAGENAME_ESCROW) {
                mapContactsToUpdate = setContactsFieldsForStage(
                    mapContactsToUpdate,
                    listContacts,
                    thisOpportunity.StageName
                );
            } else if (thisOpportunity.StageName == STAGENAME_CLOSED_WON) {
                mapContactsToUpdate = setContactsFieldsForStage(
                    mapContactsToUpdate,
                    listContacts,
                    thisOpportunity.StageName
                );
            } else if (thisOpportunity.StageName == STAGENAME_APPROVED_TO_RESELL) {
                //This condition block is a modified working version of Methods_Opportunity.updateContactStatusToCancelled
                Boolean isAllOtherCancelled = isAllOtherOpportunityHasStage(
                    STAGENAME_CANCELLED,
                    thisOpportunity,
                    mapAllOpportunitysGroupByAccount
                );
                mapContactsToUpdate = setContactForCancelled(
                    mapContactsToUpdate,
                    thisOpportunity,
                    listContacts,
                    isAllOtherCancelled
                );
            }
        }
        return mapContactsToUpdate;
    }

    /**
     * @description Method to set fields for Contacts when Closed Lost
     * @param   mapContactsToUpdate         Map of Contacts to update
     * @param   thisOpportunity             Closed Lost Opportunity
     * @param   listContactsToEvaluate      List of Contacts related to the AcccountId
     * @param   isAllClosed                 Boolean Is all other Opportunities Closed Lost
     * @return  return the Map of contacts to Update
     */
    private static Map<Id, Contact> setContactForClosedLost(
        Map<Id, Contact> mapContactsToUpdate,
        Opportunity thisOpportunity,
        List<Contact> listContactsToEvaluate,
        Boolean isAllClosed
    ) {
        if (isAllClosed) {
            for (Contact thisContact : listContactsToEvaluate) {
                if (thisContact.Account_Type__c == 'Agent')
                    continue;

                if (!mapContactsToUpdate.containsKey(thisContact.Id)) {
                    mapContactsToUpdate.put(thisContact.Id, thisContact);
                }
                Contact referencedContact = mapContactsToUpdate.get(thisContact.Id);
                if (
                    thisOpportunity.Closed_Lost_Reason__c != 'Interested in another of our communities' &&
                    thisOpportunity.Closed_Lost_Reason__c != 'our location not a fit'
                ) {
                    referencedContact.OwnerId = System.Label.ContactMarketingOwner;
                    referencedContact.Contact_Status__c = 'Closed Lost';
                    referencedContact.Closed_Lost_Reason__c = thisOpportunity.Closed_Lost_Reason__c;
                } else {
                    referencedContact.Contact_Status__c = 'NHS Engaged';
                }
            }
        }
        return mapContactsToUpdate;
    }

    /**
     * @description Method to set fields for Contacts to Cancelled
     * @param   mapContactsToUpdate         Map of Contacts to update
     * @param   thisOpportunity             Approved To Resell Opportunity
     * @param   listContactsToEvaluate      List of Contacts related to the AcccountId
     * @param   isAllOtherCancelled        Boolean Is all other Opportunities Cancelled
     * @return  return the Map of contacts to Update
     */
    private static Map<Id, Contact> setContactForCancelled(
        Map<Id, Contact> mapContactsToUpdate,
        Opportunity thisOpportunity,
        List<Contact> listContactsToEvaluate,
        Boolean isAllOtherCancelled
    ) {
        if (isAllOtherCancelled) {
            for (Contact thisContact : listContactsToEvaluate) {
                if (thisContact.Account_Type__c == 'Agent')
                    continue;

                if (!mapContactsToUpdate.containsKey(thisContact.Id)) {
                    mapContactsToUpdate.put(thisContact.Id, thisContact);
                }
                Contact referencedContact = mapContactsToUpdate.get(thisContact.Id);
                referencedContact.Contact_Status__c = 'Cancelled';
                referencedContact.OwnerId = System.Label.ContactMarketingOwner;
                referencedContact.Cancelled_Date__c = System.today();
                referencedContact.Cancel_Sale_Reason__c = thisOpportunity.Cancel_Sale_Reason__c;
            }
        }
        return mapContactsToUpdate;
    }

    /**
     * @description Method to set fields for Contacts when Closed Lost
     * @param   mapContactsToUpdate         Map of Contacts to update
     * @param   listContactsToEvaluate      List of Contacts related to the AcccountId
     * @param   thisStageName               Stage Name of the Opportunity
     * @return  return the Map of contacts to Update
     */
    private static Map<Id, Contact> setContactsFieldsForStage(
        Map<Id, Contact> mapContactsToUpdate,
        List<Contact> listContactsToEvaluate,
        String thisStageName
    ) {
        for (Contact thisContact : listContactsToEvaluate) {
            if (thisContact.Account_Type__c == 'Agent')
                continue;

            if (!mapContactsToUpdate.containsKey(thisContact.Id)) {
                mapContactsToUpdate.put(thisContact.Id, thisContact);
            }
            Contact referencedContact = mapContactsToUpdate.get(thisContact.Id);
            referencedContact.Contact_Status__c = thisStageName;

            if (thisStageName == STAGENAME_CONTRACTED) {
                referencedContact.Contracted_Date__c = System.today();
            } else if (thisStageName == STAGENAME_ESCROW) {
                referencedContact.Escrow_Date__c = System.today();
            } else if (thisStageName == STAGENAME_CLOSED_WON) {
                referencedContact.Closed_Won_Date__c = System.today();
            }
        }
        return mapContactsToUpdate;
    }

    /**
     * @description Method to evaluate and set Related Opportunity fields when Contracted or Escrow
     * @param   mapOpportunitiesToUpdate             Map of Opportunities to Update
     * @param   mapOpportunitiesToEvaluate           Map of Opportunties with Stage Name Changes
     * @param   mapAllOpportunitysGroupByAccount     Map of Opportuntites group by the Account Id
     * @return  return the Map of Opportunties to Update
     */
    public static Map<Id, Opportunity> evaluateOtherOpportunitiesForChangedStageNames(
        Map<Id, Opportunity> mapOpportunitiesToUpdate,
        Map<Id, Opportunity> mapOpportunitiesToEvaluate,
        Map<Id, List<Opportunity>> mapAllOpportunitysGroupByAccount
    ) {
        for (Opportunity thisOpportunity : mapOpportunitiesToEvaluate.values()) {
            Id thisAccountId = thisOpportunity.AccountId;
            List<Opportunity> listOpportunitiesRelatedToAccountId = mapAllOpportunitysGroupByAccount.get(thisAccountId);

            if (thisOpportunity.StageName == STAGENAME_CONTRACTED) {
                mapOpportunitiesToUpdate = setRelatedOpportunitiesAsClosedLost(
                    mapOpportunitiesToUpdate,
                    thisOpportunity,
                    listOpportunitiesRelatedToAccountId
                );
            } else if (thisOpportunity.StageName == STAGENAME_ESCROW) {
                mapOpportunitiesToUpdate = setRelatedOpportunitiesAsClosedLost(
                    mapOpportunitiesToUpdate,
                    thisOpportunity,
                    listOpportunitiesRelatedToAccountId
                );
            }
        }
        return mapOpportunitiesToUpdate;
    }

    /**
     * @description Method to set related Opportunities to Closed Lost when the Stage is in Contract Pending or later
     * @param   mapOpportunityToUpdate               Map of Opportunities to Update
     * @param   opportunityToEvaluate                Opportunity being evaluated
     * @param   listOpportunitiesRelatedToAccount    List of related Opportunities to the Accoutn Id
     * @return  return the Map of Opportunities to Update
     */
    private static Map<Id, Opportunity> setRelatedOpportunitiesAsClosedLost(
        Map<Id, Opportunity> mapOpportunityToUpdate,
        Opportunity opportunityToEvaluate,
        List<Opportunity> listOpportunitiesRelatedToAccount
    ) {
        for (Opportunity thisOpportunity : listOpportunitiesRelatedToAccount) {
            if (opportunityToEvaluate.Id == thisOpportunity.Id)
                continue;

            if (!isContractedStage(thisOpportunity.StageName)) {
                if (!mapOpportunityToUpdate.containsKey(thisOpportunity.Id)) {
                    mapOpportunityToUpdate.put(thisOpportunity.Id, thisOpportunity);
                }
                Opportunity referencedOpportunity = mapOpportunityToUpdate.get(thisOpportunity.Id);
                referencedOpportunity.StageName = STAGENAME_CLOSED_LOST;
                referencedOpportunity.Closed_Lost_Reason__c = 'Purchased In Tri Pointe Family';
            }
        }
        return mapOpportunityToUpdate;
    }

    /**
     * @description Method to Determine if the Stage is in Contract Pending or later
     * @param   thisStageName   Stage Name being evaluated
     * @return  Boolean to determine if the stage is in a contracted stage
     */
    private static Boolean isContractedStage(String thisStageName) {
        Boolean isContracted = false;
        List<String> listStagesPriorToContactPending = new List<String>{
            STAGENAME_CONTRACT_PENDING,
            STAGENAME_CONTRACTED,
            STAGENAME_ESCROW,
            STAGENAME_PENDING_CANCELLATION,
            STAGENAME_CANCELLED,
            STAGENAME_CLOSED_LOST,
            STAGENAME_CLOSED_WON,
            STAGENAME_CANCELLATION_SUBMITTED,
            STAGENAME_CANCELLATION_APPROVED,
            STAGENAME_APPROVED_TO_RESELL
        };
        if (listStagesPriorToContactPending.contains(thisStageName)) {
            isContracted = true;
        }
        return isContracted;
    }

    /**
     * @description Method to evaluate the Accounts when All Opportunties related to an Account is Closed Lost
     * @param   mapAccountsToUpdate                 Map of Accounts to update
     * @param   mapOpportunitiesToEvaluate          Map of Opportunties with Stage Name Changes
     * @param   mapAccountById                      Map of Accounts by Account Id
     * @param   mapAllOpportunitysGroupByAccount    Map of Opportuntites group by the Account Id
     * @return  return the Map of Accounts to Update
     */
    public static Map<Id, Account> evaluateAccountsForClosedLostOpportunities(
        Map<Id, Account> mapAccountsToUpdate,
        Map<Id, Opportunity> mapOpportunitiesToEvaluate,
        Map<Id, Account> mapAccountById,
        Map<Id, List<Opportunity>> mapAllOpportunitysGroupByAccount
    ) {
        for (Opportunity thisOpportunity : mapOpportunitiesToEvaluate.values()) {
            if (thisOpportunity.stageName == STAGENAME_CLOSED_LOST) {
                Account thisAccount = mapAccountById.get(thisOpportunity.AccountId);
                if (
                    thisAccount.Type != 'Agent' &&
                    isAllOtherOpportunityHasStage(
                        STAGENAME_CLOSED_LOST,
                        thisOpportunity,
                        mapAllOpportunitysGroupByAccount
                    )
                ) {
                    if (mapAccountsToUpdate.containsKey(thisAccount.Id)) {
                        mapAccountsToUpdate.get(thisAccount.Id).Type = 'Reverted';
                    } else {
                        mapAccountsToUpdate.put(thisAccount.Id, new Account(Id = thisAccount.Id, Type = 'Reverted'));
                    }
                }
            }
        }
        return mapAccountsToUpdate;
    }

    /**
     * @description Method to evaluate the Home Sites Sales Status when Opportunity stage is changed
     * @param   listNewOpportunities            List of Opportunity, Trigger.New
     * @param   mapOldOpportunties              Map of Old Opportunties, Trigger.old Map
     * @param   mapOpportunitiesByHomeSiteId    Map of Opportunitites grouped by Home Site
     * @return  return the Map of Home Sites to Update
     */
    public static Map<Id, Home_Site__c> evaluateHomeSiteSalesStatus(
        List<Opportunity> listNewOpportunities,
        Map<Id, Opportunity> mapOldOpportunties,
        Map<Id, List<Opportunity>> mapOpportunitiesByHomeSiteId
    ) {
        Map<Id, Home_Site__c> mapHomeSiteToUpdate = new Map<Id, Home_Site__c>();
        Id phase1RecordTypeId = MAP_OPPORTUNITY_RECORDTYPE_BY_DEVELOPERNAME.get('Phase_1').getRecordTypeId();
        for (Opportunity thisOpportunity : listNewOpportunities) {
            if (thisOpportunity.Home_Site_Lookup__c == null)
                continue;
            if (!mapOpportunitiesByHomeSiteId.containsKey(thisOpportunity.Home_Site_Lookup__c))
                continue;

            List<Opportunity> listHomeSiteOpportunities = mapOpportunitiesByHomeSiteId.get(
                thisOpportunity.Home_Site_Lookup__c
            );
            if (isEvaluateHomeSiteStatus(thisOpportunity.Id, listHomeSiteOpportunities))
                continue;

            Opportunity oldOpportunity = mapOldOpportunties.get(thisOpportunity.Id);
            if (thisOpportunity.StageName != oldOpportunity.StageName) {
                String salesStatus;
                if (thisOpportunity.StageName == STAGENAME_CONTRACT_PENDING) {
                    salesStatus = 'Sold';
                } else if (thisOpportunity.StageName == STAGENAME_CONTRACTED) {
                    if (
                        thisOpportunity.Sales_Reported_Date__c != null &&
                        thisOpportunity.Canceled_Date__c == null &&
                        thisOpportunity.Sales_Ratified_Date__c == null &&
                        thisOpportunity.Earnest_Deposit_Received_Met_Deposit_Min__c
                    ) {
                        salesStatus = 'Sold';
                    }
                } else if (thisOpportunity.StageName == STAGENAME_APPROVED_TO_RESELL) {
                    salesStatus = 'Available';
                } else if (thisOpportunity.StageName == STAGENAME_CLOSED_LOST) {
                    List<String> listHomeSiteStatuses = new List<String>{
                        'Not Available',
                        'Hold',
                        'Reservation',
                        'Sold'
                    };
                    if (
                        thisOpportunity.Do_not_Invoke_Process__c == false &&
                        thisOpportunity.recordTypeId != phase1RecordTypeId &&
                        listHomeSiteStatuses.contains(thisOpportunity.Homesite_Sales_Status__c)
                    ) {
                        salesStatus = 'Available';
                    }
                } else if (thisOpportunity.StageName == STAGENAME_CLOSED_WON) {
                    salesStatus = 'Closed';
                } else {
                    List<String> listOldStage = new List<String>{ STAGENAME_RESERVATION, STAGENAME_CONTRACT_PENDING };
                    List<String> listNewStage = new List<String>{
                        STAGENAME_DISCOVERY,
                        STAGENAME_PROPOSAL_DRAFT,
                        STAGENAME_PREQUALIFICATION,
                        STAGENAME_OFFER_PENDING,
                        STAGENAME_OFFER_APPROVED
                    };
                    if (
                        listOldStage.contains(oldOpportunity.StageName) &&
                        listNewStage.contains(thisOpportunity.StageName)
                    ) {
                        salesStatus = 'Available';
                    }
                }

                if (salesStatus != null && salesStatus != thisOpportunity.Homesite_Sales_Status__c) {
                    mapHomeSiteToUpdate.put(
                        thisOpportunity.Home_Site_Lookup__c,
                        new Home_Site__c(Id = thisOpportunity.Home_Site_Lookup__c, Sales_Status__c = salesStatus)
                    );
                }
            }
        }

        return mapHomeSiteToUpdate;
    }

    /**
     * @description Method to check if all related Opportunitites are in a contracted stage
     * @param   evaluateOpportunityId           Opportunity Id of the opportunity being evaluated
     * @param   listOpportunities               List of Opportunitites related to the Home Site
     * @return  Booelan if the related opportunities are in a contracted stage
     */
    public static boolean isEvaluateHomeSiteStatus(Id evaluateOpportunityId, List<Opportunity> listOpportunities) {
        Boolean isEvaluateHomeSiteStatus = false;
        List<String> listStages = new List<String>{
            STAGENAME_CONTRACT_PENDING,
            STAGENAME_CONTRACTED,
            STAGENAME_ESCROW,
            STAGENAME_PENDING_CANCELLATION,
            STAGENAME_CLOSED_WON,
            STAGENAME_CANCELLATION_SUBMITTED,
            STAGENAME_CANCELLATION_APPROVED,
            STAGENAME_CANCELLED,
            STAGENAME_HOLD,
            STAGENAME_RESERVATION
        };
        for (Opportunity thisOpportunity : listOpportunities) {
            if (evaluateOpportunityId == thisOpportunity.Id)
                continue;

            if (listStages.contains(thisOpportunity.StageName)) {
                isEvaluateHomeSiteStatus = true;
                break;
            }
        }
        return isEvaluateHomeSiteStatus;
    }

    /**
     * @description Method to evaluate DateTime from an Opportunity with the DST Start/End Date
     * @param   thisOpportunity     Opportunity record from Trigger
     * @param   opportunityField    Opportunity DateTime field that is being evaluated
     * @return  Date value of the Sales Ratified Date
     */
    private static Date getEstDate(Opportunity thisOpportunity, Schema.SObjectField opportunityField) {
        DateTime estimatedDatedTime;
        DateTime dateTimeValue = (DateTime) thisOpportunity.get(opportunityField);

        if (
            dateTimeValue.date() > thisOpportunity.DST_Start_Date__c &&
            dateTimeValue.date() < thisOpportunity.DST_End_Date__c
        ) {
            estimatedDatedTime = dateTimeValue.addHours(CUTOFF_HOURS_FOR_BUYER_SELLER_DATE);
        } else if (dateTimeValue.date() == thisOpportunity.DST_Start_Date__c) {
            if (dateTimeValue.time() >= DST_TIME) {
                estimatedDatedTime = dateTimeValue.addHours(CUTOFF_HOURS_FOR_BUYER_SELLER_DATE);
            } else {
                estimatedDatedTime = dateTimeValue.addHours(0);
            }
        } else if (dateTimeValue.date() == thisOpportunity.DST_End_Date__c) {
            if (dateTimeValue.time() < DST_TIME) {
                estimatedDatedTime = dateTimeValue.addHours(CUTOFF_HOURS_FOR_BUYER_SELLER_DATE);
            } else {
                estimatedDatedTime = dateTimeValue.addHours(0);
            }
        } else {
            estimatedDatedTime = dateTimeValue.addHours(0);
        }
        return estimatedDatedTime.date();
    }

    /**
     * @description Method to set PCC Milestone Fields for update when Probability has changed
     * @param   mapPCCMilestonesToUpdate                Map of PCC Milestones to Update
     * @param   listOpportunity                         List of Opportunity Trigger.New
     * @param   mapOldOpportunityById                      Map of Old Opportunity Trigger.OldMap
     * @param   mapPCCMilestonesGroupByOpportunityId    Map Of PCC Milestone Records grouped by Opportunity Id
     * @return  Map of PCC Milestones to Update
     */
    public static Map<Id, Pre_Closing_Closing_Milestone__c> evaluatePCCMilestoneFieldsOnProbabilityChange(
        Map<Id, Pre_Closing_Closing_Milestone__c> mapPCCMilestonesToUpdate,
        List<Opportunity> listOpportunity,
        Map<Id, Opportunity> mapOldOpportunityById,
        Map<Id, List<Pre_Closing_Closing_Milestone__c>> mapPCCMilestonesGroupByOpportunityId
    ) {
        String probabilityTemplate = '{0}%';
        for (Opportunity thisOpportunity : listOpportunity) {
            if (!mapPCCMilestonesGroupByOpportunityId.containsKey(thisOpportunity.Id))
                continue;

            Opportunity oldOpportunity = mapOldOpportunityById.get(thisOpportunity.Id);
            if (thisOpportunity.Probability != oldOpportunity.Probability) {
                List<String> stringParameters = new List<String>{ String.valueOf(thisOpportunity.Probability) };
                String thisProbability = String.format(probabilityTemplate, stringParameters);
                for (
                    Pre_Closing_Closing_Milestone__c thisPCCMilestone : mapPCCMilestonesGroupByOpportunityId.get(
                        thisOpportunity.Id
                    )
                ) {
                    if (!mapPCCMilestonesToUpdate.containsKey(thisPCCMilestone.Id)) {
                        mapPCCMilestonesToUpdate.put(thisPCCMilestone.Id, thisPCCMilestone);
                    }
                    Pre_Closing_Closing_Milestone__c referencedPCCMilestone = mapPCCMilestonesToUpdate.get(
                        thisPCCMilestone.Id
                    );
                    referencedPCCMilestone.Probability1__c = thisProbability;
                }
            }
        }
        return mapPCCMilestonesToUpdate;
    }

    /**
     * @description Method to generate PCC Milestones for insert
     * @param   listOpportunityContracted                               List of Opportunity in Contract stages
     * @param   mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates  Map of Division Site Ids keyed by Community Site Ids with PCC Templates
     * @param   mapExistingPCCMilestonesGroupByOpportunityId             Map Of PCC Milestone Records grouped by Opportunity Id
     * @return  Map of PCC Milestones to Update
     */
    public static List<Pre_Closing_Closing_Milestone__c> generatePCCMilestonesOnContracted(
        List<Opportunity> listOpportunityContracted,
        Map<Id, Id> mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates,
        Map<Id, List<Pre_Closing_Closing_Milestone__c>> mapExistingPCCMilestonesGroupByOpportunityId
    ) {
        List<Pre_Closing_Closing_Milestone__c> listPccMilestoneToInsert = new List<Pre_Closing_Closing_Milestone__c>();
        String probabilityTemplate = '{0}%';
        for (Opportunity contractedOpportunity : listOpportunityContracted) {
            if (mapExistingPCCMilestonesGroupByOpportunityId.containsKey(contractedOpportunity.Id))
                continue;
            if (contractedOpportunity.Community_Site__c == null)
                continue;
            if (
                mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates.containsKey(
                    contractedOpportunity.Community_Site__c
                )
            ) {
                List<String> stringParameters = new List<String>{ String.valueOf(contractedOpportunity.Probability) };
                String thisProbability = String.format(probabilityTemplate, stringParameters);
                Id divisionSettingId = mapDivisionSiteIdByCommunityIdsWithRelatedPccTemplates.get(
                    contractedOpportunity.Community_Site__c
                );
                Pre_Closing_Closing_Milestone__c pccMilestone = new Pre_Closing_Closing_Milestone__c(
                    Division_Setting__c = divisionSettingId,
                    Opportunity__c = contractedOpportunity.Id,
                    Probability1__c = thisProbability
                );
                listPccMilestoneToInsert.add(pccMilestone);
            }
        }
        return listPccMilestoneToInsert;
    }

    /**
     * @description Method to set Quote Frozen Fields when Opportunity is contracted
     * @param   mapQuoteToUpdate                Map of Quotes to Update
     * @param   listOpportunity                 List of Opportunity Trigger.New
     * @param   mapOldOpportunityById           Map of Old Opportunity Trigger.OldMap
     * @param   mapQuotesGroupByOpportunityId   Map of Quote Records grouped by Opportunity Id
     * @return  Map of Quotes to Update
     */
    public static Map<Id, SBQQ__Quote__c> evaluateQuoteFieldsOnContracted(
        Map<Id, SBQQ__Quote__c> mapQuoteToUpdate,
        List<Opportunity> listOpportunity,
        Map<Id, Opportunity> mapOldOpportunityById,
        Map<Id, List<SBQQ__Quote__c>> mapQuotesGroupByOpportunityId
    ) {
        for (Opportunity thisOpportunity : listOpportunity) {
            if (!mapQuotesGroupByOpportunityId.containsKey(thisOpportunity.Id))
                continue;
            Opportunity oldOpportunity = mapOldOpportunityById.get(thisOpportunity.Id);

            if (
                thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                (thisOpportunity.StageName == STAGENAME_CONTRACT_PENDING &&
                oldOpportunity.StageName == STAGENAME_ESCROW)
            ) {
                for (SBQQ__Quote__c thisQuote : mapQuotesGroupByOpportunityId.get(thisOpportunity.Id)) {
                    if (thisQuote.SBQQ__Primary__c != true)
                        continue;
                    if (!mapQuoteToUpdate.containsKey(thisQuote.Id)) {
                        mapQuoteToUpdate.put(thisQuote.Id, thisQuote);
                    }
                    SBQQ__Quote__c referencedQuote = mapQuoteToUpdate.get(thisQuote.Id);
                    referencedQuote.Frozen_Base_Price__c = thisQuote.Base_Price__c;
                    referencedQuote.Frozen_Lot_Premium__c = thisQuote.Homesite_Premium__c;
                    referencedQuote.Frozen_Mgmt_Adjustment__c = thisQuote.Management_Price_Adjustment__c;
                    referencedQuote.Frozen_Pre_plotted_Option__c = thisQuote.Pre_Plotted_Options__c;
                    referencedQuote.Frozen_Customer_Selected_Option__c = thisQuote.Buyer_Selected_Options__c;
                    referencedQuote.Frozen_Discount__c = thisQuote.Discounts__c;
                }
            }
        }
        return mapQuoteToUpdate;
    }

    /**
     * @description Method to determine if all other Opportunites related to the Account Id is specified StageName
     * @param   specifiedStageName                 Stage name to evaluate the other opportuntiies with
     * @param   evaluateOpportunity                 Opportunity being evaluated
     * @param   mapAllOpportuntiesByAccountId       Map of Opportunties Grouped by the Account Id
     * @return   Boolean if all other opportunities is the specified stagename
     */
    private static Boolean isAllOtherOpportunityHasStage(
        String specifiedStageName,
        Opportunity evaluateOpportunity,
        Map<Id, List<Opportunity>> mapAllOpportuntiesByAccountId
    ) {
        Boolean isAllOpportunityHasStage = true;
        for (Opportunity thisOpportunity : mapAllOpportuntiesByAccountId.get(evaluateOpportunity.AccountId)) {
            if (evaluateOpportunity.Id == thisOpportunity.Id)
                continue;

            if (thisOpportunity.StageName != specifiedStageName) {
                isAllOpportunityHasStage = false;
                break;
            }
        }
        return isAllOpportunityHasStage;
    }

    /**
     * @description Method to Get Contact Ids from Opportunity Contact Roles
     * @param setNhsAppointmentOpportunityIds   Set of Opportunity Ids
     * @param listOpportunityContactRoles       List of OpportunityContactRoles
     * @return  Id of the Enqueued Job
     */
    public static Set<Id> getContactIdsFromOpportunityContactRoles(
        Set<Id> setNhsAppointmentOpportunityIds,
        List<OpportunityContactRole> listOpportunityContactRoles
    ) {
        Set<Id> setContactIds = new Set<Id>();
        for (OpportunityContactRole thisOpportunityContactRole : listOpportunityContactRoles) {
            if (setNhsAppointmentOpportunityIds.contains(thisOpportunityContactRole.OpportunityId)) {
                setContactIds.add(thisOpportunityContactRole.ContactId);
            }
        }
        return setContactIds;
    }

    /**
     * @description Method to generate Interation Event on Insert dependent on Stage Names and other conditions
     * @param listNewOpportunity    List of Opportunities, Trigger.new
     * @param mapOldOpportunity     Map of Old Opportunities, Trigger.oldMap
     * @return  Map of Integration Events keyed by Opportunity Ids
     */
    public static Map<Id, Integration_Event__c> evaluateIntegrationEvent(
        List<Opportunity> listNewOpportunity,
        Map<Id, Opportunity> mapOldOpportunity
    ) {
        Map<Id, Integration_Event__c> mapIntegrationEventToInsertByOpportunityId = new Map<Id, Integration_Event__c>();

        if (System.Label.IntegrationUserProfileId.contains(UserInfo.getProfileId())) {
            return mapIntegrationEventToInsertByOpportunityId;
        }

        for (Opportunity thisOpportunity : listNewOpportunity) {
            Opportunity oldOpportunity = mapOldOpportunity.get(thisOpportunity.Id);

            if (!thisOpportunity.Phase_2_Division__c)
                continue;
            if (
                thisOpportunity.Floor_Plan_Lookup__c == null ||
                thisOpportunity.Home_Site_Lookup__c == null ||
                thisOpportunity.Elevation_Form__c == null
            )
                continue;

            Integration_Event__c thisIntegrationEvent;
            if (
                (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                thisOpportunity.StageName == STAGENAME_ESCROW) &&
                thisOpportunity.LastModifiedDate != oldOpportunity.LastModifiedDate &&
                thisOpportunity.Buyer_Signed_Cancellation_Document_Date__c == null
            ) {
                thisIntegrationEvent = new Integration_Event__c(
                    Opportunity__c = thisOpportunity.Id,
                    Type__c = 'Sale',
                    Transaction_Type__c = 'Sale',
                    Brand__c = thisOpportunity.Brand__c,
                    Sales_Date__c = thisOpportunity.Sales_Reported_Date__c,
                    Code_Source__c = 'Any change while in contracted or escrow'
                );
            } else if (
                thisOpportunity.Canceled_Date__c != null &&
                oldOpportunity.Canceled_Date__c == null &&
                ((thisOpportunity.StageName != STAGENAME_CLOSED_WON && thisOpportunity.SBQQ__PrimaryQuote__c != null) ||
                (thisOpportunity.StageName == STAGENAME_CANCELLED &&
                oldOpportunity.StageName == STAGENAME_CANCELLED))
            ) {
                thisIntegrationEvent = new Integration_Event__c(
                    Opportunity__c = thisOpportunity.Id,
                    Type__c = 'Sale',
                    Transaction_Type__c = 'Cancelled',
                    Brand__c = thisOpportunity.Brand__c,
                    Canceled_Date__c = thisOpportunity.Canceled_Date__c,
                    Code_Source__c = 'Cancelled'
                );
            } else if (
                thisOpportunity.StageName == STAGENAME_CLOSED_WON &&
                oldOpportunity.StageName != STAGENAME_CLOSED_WON &&
                thisOpportunity.SBQQ__PrimaryQuote__c != null
            ) {
                thisIntegrationEvent = new Integration_Event__c(
                    Opportunity__c = thisOpportunity.Id,
                    Type__c = 'Sale',
                    Transaction_Type__c = 'Closed',
                    Brand__c = thisOpportunity.Brand__c,
                    Closed_Date__c = thisOpportunity.CloseDate
                );
            } else if (
                thisOpportunity.SBQQ__PrimaryQuote__c != null &&
                (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                thisOpportunity.StageName == STAGENAME_ESCROW) &&
                (thisOpportunity.Contact_Role_Summary__c != oldOpportunity.Contact_Role_Summary__c ||
                thisOpportunity.Broker_of_Record__c != oldOpportunity.Broker_of_Record__c ||
                thisOpportunity.Escrow_Representative__c != oldOpportunity.Escrow_Representative__c ||
                thisOpportunity.Lender_Contact2__c != oldOpportunity.Lender_Contact2__c)
            ) {
                thisIntegrationEvent = new Integration_Event__c(
                    Opportunity__c = thisOpportunity.Id,
                    Type__c = 'Sale',
                    Transaction_Type__c = 'Sale',
                    Brand__c = thisOpportunity.Brand__c,
                    Code_Source__c = 'Contact Change'
                );
            } else if (
                thisOpportunity.SBQQ__PrimaryQuote__c != null &&
                (thisOpportunity.StageName == STAGENAME_CONTRACTED ||
                thisOpportunity.StageName == STAGENAME_ESCROW ||
                thisOpportunity.StageName == STAGENAME_RESERVATION) &&
                (thisOpportunity.Total_Unpaid_Deposits_all_types__c !=
                oldOpportunity.Total_Unpaid_Deposits_all_types__c ||
                thisOpportunity.Total_Paid_Deposits_all_types__c != oldOpportunity.Total_Paid_Deposits_all_types__c)
            ) {
                thisIntegrationEvent = new Integration_Event__c(
                    Opportunity__c = thisOpportunity.Id,
                    Type__c = 'Sale',
                    Brand__c = thisOpportunity.Brand__c,
                    Code_Source__c = 'Deposit Change'
                );
                if (thisOpportunity.StageName == STAGENAME_RESERVATION) {
                    thisIntegrationEvent.Transaction_Type__c = 'Reservation';
                    thisIntegrationEvent.Reservation_Date__c = thisOpportunity.Reservation_Date__c;
                } else {
                    thisIntegrationEvent.Transaction_Type__c = 'Sale';
                    thisIntegrationEvent.Sales_Date__c = thisOpportunity.Sales_Reported_Date__c;
                }
            }

            if (thisIntegrationEvent != null) {
                mapIntegrationEventToInsertByOpportunityId.put(thisOpportunity.Id, thisIntegrationEvent);
            }
        }

        return mapIntegrationEventToInsertByOpportunityId;
    }

    /**
     * @description Method to generate Interation Event on Insert dependent on Stage Names and other conditions
     * @param mapOpportunityToUpdate                        Map of Opportunities to update
     * @param mapNewOpportunity                             Map of Opportunities, Trigger.newMap
     * @param mapIntegrationEventToInsertByOpportunityId    Map of Integration Events keyed by Opportunity Ids
     * @return  Map of Opportunities to update
     */
    public static Map<Id, Opportunity> generateUpdatedOpportunityFromIntergrationEvents(
        Map<Id, Opportunity> mapOpportunityToUpdate,
        Map<Id, Opportunity> mapNewOpportunity,
        Map<Id, Integration_Event__c> mapIntegrationEventToInsertByOpportunityId
    ) {
        List<Opportunity> listOpportunityToUpdate = new List<Opportunity>();
        for (Id opportunityId : mapIntegrationEventToInsertByOpportunityId.keySet()) {
            Opportunity thisOpportunity = mapNewOpportunity.get(opportunityId);
            if (thisOpportunity.Sent_to_ERP__c == false) {
                if (mapOpportunityToUpdate.containsKey(opportunityId)) {
                    mapOpportunityToUpdate.get(opportunityId).Sent_to_ERP__c = true;
                } else {
                    mapOpportunityToUpdate.put(
                        opportunityId,
                        new Opportunity(Id = opportunityId, Sent_to_ERP__c = true)
                    );
                }
            }
        }
        return mapOpportunityToUpdate;
    }

    /**
     * @description Method will retrieve all fields from Schema for a given object
     * @param   sobjectDescribe     Schema sObject type
     * @return  list of field names
     */
    private static List<String> getAllFields(Schema.DescribeSObjectResult sobjectDescribe) {
        Map<String, Schema.SObjectField> mapSobjectFieldsByFieldName = sobjectDescribe.fields.getMap();
        List<String> listFieldName = new List<String>(mapSobjectFieldsByFieldName.keySet());
        return listFieldName;
    }

    /**
     * @description Method will create a dynamic SOQL query using a field set or defaults to all fields in an object
     * @param   thisSobjectType      Used to indicate the Object Typeg
     * @param   setFilterIds         Set of Ids that the soql query will filter on
     * @return  list of records return from the SOQL query
     */
    private static List<SObject> sobjectSelector(Schema.SObjectType thisSobjectType, Set<Id> setFilterIds) {
        Schema.DescribeSObjectResult sobjectDescribe = thisSobjectType.getDescribe();
        List<String> listFieldName = getAllFields(sobjectDescribe);
        String query = 'SELECT ' + String.join(listFieldName, ', ');
        query += ' FROM ' + sobjectDescribe.getName();
        query += ' WHERE Id IN : setFilterIds';

        List<Sobject> listResults = Database.query(query);

        return listResults;
    }

    /**
     * @description Asynchrnous Future method to invoke Methods_SAW.generateSAW
     * @param   setQuoteIds     Set of Quote Ids
     */
    @future
    private static void futureCreateCancelOffer(Set<Id> setQuoteIds) {
        List<SBQQ__Quote__c> listQuotes = (List<SBQQ__Quote__c>) sobjectSelector(
            SBQQ__Quote__c.SObjectType,
            setQuoteIds
        );
        Methods_SAW.generateSAW(listQuotes, 'Cancellation');
    }

    /**
     * @description Method to set the field Created Cancellation offer and invoke future method futureCreateCancelOffer
     * @param   listNewOpportunity    List of Opportunity, Trigger.new
     */
    public static void setAndEvaluateCancelOffer(List<opportunity> listNewOpportunity) {
        Set<Id> setCancelledQuoteIds = new Set<Id>();
        String oldOppStagename = '';
        for (Opportunity thisOpportunity : listNewOpportunity) {
            if (
                !thisOpportunity.Created_Cancellation_Offer__c &&
                thisOpportunity.Cancel_Approval_Status__c == 'Approved' &&
                (thisOpportunity.Buyer_Signed_Cancellation_Document_Date__c != null ||
                thisOpportunity.Buyer_Unavailable_to_Sign_Cancellation__c) &&
                thisOpportunity.Seller_Signed_Cancellation_Document_Date__c != null
            ) {
                setCancelledQuoteIds.add(thisOpportunity.SBQQ__PrimaryQuote__c);

                thisOpportunity.Created_Cancellation_Offer__c = true;
            }
        }
        if (!setCancelledQuoteIds.isEmpty()) {
            OpportunityTriggerHelper.futureCreateCancelOffer(setCancelledQuoteIds);
        }
    }
}