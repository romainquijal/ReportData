/**
 * @description       : ReportDataExplorer class is a controller for fetching report data.
 *                      The class retrieves report data from Salesforce and transforms it into a more readable format.
 * @author            : Romain QUIJAL
 * @group             : 
 * @last modified on  : 03-20-2023
 * @last modified by  : Romain QUIJAL
**/
public with sharing class ReportDataExplorer {

    /**
     * ReportData class holds the structure for report data.
     */
    public class ReportData{
        @AuraEnabled public List<CustomColumn> customColumns;
        @AuraEnabled public String customValues;
    }

    /**
     * CustomColumn class holds the structure for columns in report data.
     */
    public class CustomColumn{
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String type;
        @Auraenabled public Boolean sortable;
    }

    public static Reports.reportResults results;
    public static List<CustomColumn> customColumns;
    public static List<Map<String, Object>> customValues;
    public static List<String> columnWithValue;
    public static List<String> columnWithValueDate;


    @AuraEnabled
    public static string executeReportAsync(String reportDeveloperName, String filterByCurrentRecord, String objectId){
        try {
            List <Report> reportList = [SELECT Id,DeveloperName FROM Report WHERE DeveloperName = :reportDeveloperName.escapeHtml4()];
            String reportId = (String)reportList.get(0).get('Id');

            // Declare the reportInstance variable
            Reports.ReportInstance reportInstance;

            // Describe the report and get its metadata
            Reports.ReportDescribeResult describe = Reports.ReportManager.describeReport(reportId);
            Reports.ReportMetadata reportMd = describe.getReportMetadata();

            // Filter the report by the current record if specified
            if(filterByCurrentRecord == 'true'){
                
                List<Reports.ReportFilter> listReportMdt = reportMd.getReportFilters();
                if(listReportMdt.size() != 0){
                    Reports.ReportFilter filter = listReportMdt[0];
                    filter.setValue(objectId);
                }
                reportInstance = Reports.ReportManager.runAsyncReport(reportId, reportMd, true);
            } else {
                reportInstance = Reports.ReportManager.runAsyncReport(reportId, true);
            }
            return reportInstance.getId();


        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getReportInstance(String reportInstanceId) {
        return Reports.ReportManager.getReportInstance(reportInstanceId).getStatus();
    }

    /**
     * getReportData method retrieves report data and returns a ReportData object.
     * @param reportDeveloperName The developer name of the report to fetch data from.
     * @param filterByCurrentRecord A flag indicating whether to filter by the current record or not.
     * @param objectId The ID of the object to filter by if filterByCurrentRecord is true.
     * @return ReportData A custom report data object containing the columns and values.
     */
    @AuraEnabled
    public static ReportData getReportData(String reportInstanceId, String configFilterSortable){
        // Wait for the report execution to complete and get the results
        results = Reports.ReportManager.getReportInstance(reportInstanceId).getReportResults();
        // Initialize variables
        List<String> columnType = new List<String>();
        customColumns = new List<CustomColumn>();
        customValues = new List<Map<String, Object>>();
        columnWithValue = new List<String>();
        columnWithValueDate = new List<String>();
        Map<String, Object> mapValues = new Map<String, Object>();

        // Process the groupings down and columns in the report results
        Reports.Dimension dim = results.getGroupingsDown();
        List<Reports.GroupingValue> groupingVals = dim.getGroupings();
        Reports.ReportExtendedMetadata metadata = results.getReportExtendedMetadata();
        Map<String,Reports.DetailColumn> columnsApiName = metadata.getDetailColumnInfo();
        Map<String,Reports.GroupingColumn> columnsGroupApiName = metadata.getGroupingColumnInfo();

        // Process grouping columns
        for(String keyGroup : columnsGroupApiName.KeySet()){
            CustomColumn customColumn = new CustomColumn();
            customColumn.type = getColumnType(columnsGroupApiName.get(keyGroup).getDataType());
            customColumn.label = columnsGroupApiName.get(keyGroup).getLabel();
            customColumn.fieldName = columnsGroupApiName.get(keyGroup).getName();
            if(configFilterSortable == 'true'){
                customColumn.sortable = true;
            } else {
                customColumn.sortable = false;
            }
            customColumns.add(customColumn);
            if(customColumn.type == 'percent'){
                columnWithValue.add(customColumn.fieldName);
            } else if(customColumn.type != 'text'){
                columnWithValueDate.add(customColumn.fieldName);
            }
        }
        // Process detail columns
        for(String key : columnsApiName.KeySet()){
            
            CustomColumn customColumn = new CustomColumn();
            customColumn.type = getColumnType(columnsApiName.get(key).getDataType());
            customColumn.label = columnsApiName.get(key).getLabel();
            customColumn.fieldName = columnsApiName.get(key).getName();
            if(configFilterSortable == 'true'){
                customColumn.sortable = true;
            } else {
                customColumn.sortable = false;
            }
            customColumns.add(customColumn);
            if(customColumn.type == 'percent'){
                columnWithValue.add(customColumn.fieldName);
            } else if(customColumn.type == 'date'){
                columnWithValueDate.add(customColumn.fieldName);
            }
        }
        // Process grouping values
        if(groupingVals.size() != 0){
            getGroupingValue(groupingVals, 0, mapValues);
        } else {
            // If there are no grouping values, process the facts
            MAP<String,Reports.ReportFact> tempMap = results.getFactMap();


            for(String key : tempMap.KeySet()){
                Reports.ReportFactWithDetails temp = (Reports.ReportFactWithDetails)tempMap.get(key);

                List<Reports.ReportDetailRow> dataRows = temp.getRows();

                for(Reports.ReportDetailRow dataRow : temp.getRows()){
                    Integer i = 0;
                    mapValues = new Map<String, Object>();
                    for(Reports.ReportDataCell dataCell : dataRow.getDataCells()){
                        if(columnWithValue.contains(customColumns[i].fieldName)){
                            mapValues.put(customColumns[i].fieldName, (Decimal)dataCell.getValue() * 0.01);
                        } else if(columnWithValueDate.contains(customColumns[i].fieldName)){
                            mapValues.put(customColumns[i].fieldName, dataCell.getValue());
                        } else {
                            mapValues.put(customColumns[i].fieldName, dataCell.getLabel());
                        }
                        i++;
                    }
                    customValues.add(mapValues);
                }  
            } 
        }
        // Prepare the final report data object
        ReportData reportData = new ReportData();
        reportData.customColumns = customColumns;
        reportData.customValues = JSON.serialize(customValues);
        
        return reportData;
    }

    /**
     * getGroupingValue method processes the grouping values and stores the data in customValues.
     * @param groupList A list of Reports.GroupingValue objects.
     * @param startingValue An integer representing the starting index of the columns.
     */
    public static void getGroupingValue(List<Reports.GroupingValue> groupList, Integer startingValue, Map<String, Object> mapValueRec){
        Map<String, Object> mapValues = new Map<String, Object>();
        mapValues.putAll(mapValueRec);
        for(Reports.GroupingValue groupingVal : groupList){
            Integer i = startingValue;
            if(groupingVal.getGroupings().size() == 0){
                String factMapKey = groupingVal.getKey() + '!T';
                Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get(factMapKey);
                
                for(Reports.ReportDetailRow dataRow : factDetails.getRows()){
                    mapValues = new Map<String, Object>();
                    mapValues.putAll(mapValueRec);

                    if(columnWithValue.contains(customColumns[i].fieldName)){
                        mapValues.put(customColumns[i].fieldName, (Decimal)groupingVal.getValue() * 0.01);
                    } else if(columnWithValueDate.contains(customColumns[i].fieldName)){
                        mapValues.put(customColumns[i].fieldName, groupingVal.getValue());
                    } else {
                        mapValues.put(customColumns[i].fieldName, groupingVal.getLabel());
                    }
                    i++;
                    for(Reports.ReportDataCell dataCell : dataRow.getDataCells()){
                        if(columnWithValue.contains(customColumns[i].fieldName)){
                            mapValues.put(customColumns[i].fieldName, (Decimal)dataCell.getValue() * 0.01);
                        } else if(columnWithValueDate.contains(customColumns[i].fieldName)){
                            mapValues.put(customColumns[i].fieldName, dataCell.getValue());
                        } else {
                            mapValues.put(customColumns[i].fieldName, dataCell.getLabel());
                        }
                        i++;
                    }
                    customValues.add(mapValues);
                    i = startingValue;
                }
            } else {

                if(columnWithValue.contains(customColumns[i].fieldName)){
                    mapValues.put(customColumns[i].fieldName, (Decimal)groupingVal.getValue() * 0.01);
                } else if(columnWithValueDate.contains(customColumns[i].fieldName)){
                    mapValues.put(customColumns[i].fieldName, groupingVal.getValue());
                } else {
                    mapValues.put(customColumns[i].fieldName, groupingVal.getLabel());
                }

                //customValues.add(mapValues);
                getGroupingValue(groupingVal.getGroupings(), i+1, mapValues);
            }
            
        }
    }

    /**
     * getColumnType method maps Reports.ColumnDataType to a more readable data type for lightning datatable.
     * @param dataType The Reports.ColumnDataType to map.
     * @return String A more readable data type.
     */
    public static String getColumnType(Reports.ColumnDataType dataType){
        switch on dataType {
            when BOOLEAN_DATA {
                return 'boolean';
            }
            when COMBOBOX_DATA {
                return 'text';
            }
            when CURRENCY_DATA {
                return 'currency';
            }
            when DATETIME_DATA {
                return 'date';
            }
            when DATE_DATA {
                return 'date';
            }
            when DOUBLE_DATA {
                return 'number';
            }
            when EMAIL_DATA {
                return 'email';
            }
            when ID_DATA {
                return 'text';
            }
            when INT_DATA {
                return 'number';
            }
            when MULTIPICKLIST_DATA {
                return 'text';
            }
            when PERCENT_DATA {
                return 'percent';
            }
            when PHONE_DATA {
                return 'phone';
            }
            when PICKLIST_DATA {
                return 'text';
            }
            when REFERENCE_DATA {
                return 'text';
            }
            when STRING_DATA {
                return 'text';
            }
            when TEXTAREA_DATA {
                return 'text';
            }
            when TIME_DATA {
                return 'text';
            }
            when URL_DATA {
                return 'url';
            }
            when else {
                return 'text';
            }
        }
    }

    
}
