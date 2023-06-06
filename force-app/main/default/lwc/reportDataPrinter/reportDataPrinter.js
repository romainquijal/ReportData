import { api, LightningElement, track } from 'lwc';
import getReportData from "@salesforce/apex/ReportDataExplorer.getReportData";
import executeReportAsync from "@salesforce/apex/ReportDataExplorer.executeReportAsync";
import getReportInstance from "@salesforce/apex/ReportDataExplorer.getReportInstance";


export default class ReportDataPrinter extends LightningElement {
    @api recordId;
    @api configReportDeveloperName;
    @api configFilterByCurrentRecord;
    @api height;
    @api configFilterSortable;
    showSpinner = true;
    error = '';
    showError = false;
    showData = false;

    @track reportData;
    @track sortDirection;
    @track sortedBy;

    connectedCallback() { 
        executeReportAsync({ 
            reportDeveloperName: this.configReportDeveloperName,
            filterByCurrentRecord: this.configFilterByCurrentRecord,
            objectId: this.recordId
         })
        .then(result => {
            const reportInstanceId = result;
            let interval = setInterval(async () => {
                const reportInstanceStatus = await getReportInstance({ reportInstanceId: reportInstanceId })
                .catch(error =>{console.log('---error----' +error)});

                if (reportInstanceStatus === 'Success') {
                    clearInterval(interval);
                    getReportData({ reportInstanceId: reportInstanceId, configFilterSortable: this.configFilterSortable })
                    .then(result =>{
                        this.reportData = JSON.parse(JSON.stringify(result)); // Process the report data here
                        this.showSpinner = false;
                        this.showData = true;
                        this.showError = false;
                        this.error = '';
                        this.reportData.customValues = JSON.parse(this.reportData.customValues);
                    }).catch(error => {
                        console.log('---error---'+JSON.stringify(error));
                    });
                    
                } else if (reportInstanceStatus === 'Error') {
                    clearInterval(interval);
                    this.showSpinner = false;
                    this.showError = false;
                    this.error = 'Error when fetching Report';
                }
            }, 1000);

        })
        .catch(error => {
            console.log('-------error-------------'+JSON.stringify(error));
            this.showSpinner = false;
            this.showError = true;
            this.showData = false;
            this.error = JSON.stringify(error);
        })
    }

    handleClick(event) {
        executeReportAsync({ 
            reportDeveloperName: this.configReportDeveloperName,
            filterByCurrentRecord: this.configFilterByCurrentRecord,
            objectId: this.recordId
         })
        .then(result => {
            const reportInstanceId = result;
            let interval = setInterval(async () => {
                const reportInstanceStatus = await getReportInstance({ reportInstanceId: reportInstanceId })
                .catch(error =>{console.log('---error----' +JSON.stringify(error))});

                if (reportInstanceStatus === 'Success') {
                    this.resetVariable();
                    clearInterval(interval);
                    getReportData({ reportInstanceId: reportInstanceId, configFilterSortable: this.configFilterSortable })
                    .then(result =>{
                        this.reportData = JSON.parse(JSON.stringify(result)); // Process the report data here
                        this.showSpinner = false;
                        this.showData = true;
                        this.showError = false;
                        this.error = '';
                        this.reportData.customValues = JSON.parse(this.reportData.customValues);
                    }).catch(error => {
                        console.log('---error---'+JSON.stringify(error));
                    });
                } else if (reportInstanceStatus === 'Error') {
                    clearInterval(interval);
                    this.showSpinner = false;
                    this.showError = false;
                    this.error = 'Error when fetching Report';
                }
            }, 1000);

        })
        .catch(error => {
            console.log('-------error-------------'+JSON.stringify(error));
            this.showSpinner = false;
            this.showError = true;
            this.showData = false;
            this.error = JSON.stringify(error);
        })
    }

    resetVariable(){
        this.showSpinner = true;
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                  return primer(x[field]);
              }
            : function (x) {
                  return x[field];
              };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.reportData.customValues];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.reportData.customValues = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }

    get componentStyle() {
        return `height:${this.height}px;`;
    }
    

}