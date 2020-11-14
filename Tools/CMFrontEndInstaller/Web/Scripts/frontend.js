/// <reference path="jquery-1.9.1.js" />
/// <reference path="knockout-2.1.0.js" />

// *************
// Variables
// *************
var minWindowHeight = 720;
var activeTab = null;
var activeSubTab = null;
var appGridRowHeight = 25;
var appGridOrigHeight = 150;
var timeouts = 0;
// setting this globally so it can be called from other viewmodels
var computerVM = null;


if (!String.prototype.format) {
    String.prototype.format = function () {
        var args = arguments;
        return this.replace(/{(\d+)}/g, function (match, number) {
            return typeof args[number] != 'undefined'
              ? args[number]
              : match
            ;
        });
    };
}

$(document).ajaxError(function(x, e) {
    if (e.status == 401 || e.status == 403) {
        $("#comErrorText").text("Authorization Lost! Refreshing...");
        $("#comErrorPopup").show();
        setTimeout(function() {
            location.reload(true);
        }, 3000);
    }
    else if (e.status == 0 || e == 'timeout') {
        timeouts++;
        if (timeouts >= 2) {
            $("#comErrorText").text("Multipule timeouts! Refresh page.");
            $("#comErrorPopup").show();
        }
    } else {
        console.log("Unhandled communication error!");
    }
});



function ReportsViewModel() {
    var self = this;
    self.reportServer = "";
    self.siteCode = "";

    self.reports = ko.observableArray([]);
    
    function report(root, name, url) {
        var self = this;
        self.name = name;
        self.url = url;

        self.openReport = function() {
            var win = window.open("http://" + root.reportServer + "/ReportServer/Pages/ReportViewer.aspx?" + String(url).format(root.siteCode, computerVM.name()), '_blank');
            win.focus();
        };
    };

    self.add = function(name, url) {
        self.reports.push(new report(self, name, url));
    };
}

function TaskViewModel() {
    var self = this;
    self.grid = null;
    
    self.items = ko.observableArray([]);

    function TaskItem(root, id, description, computerName, userName, started, updated, percentComplete, changed) {
        var self = this;

        self.id = id;
        self.description = description;
        self.computerName = computerName;
        self.userName = userName;
        self.started = started;
        self.updated = ko.observable(updated);
        self.percentComplete = ko.observable(percentComplete);
        self.changed = ko.observable(changed);

        self.remove = function () {
            root.remove(self);
        };

        self.update = function (updated, percentComplete) {
            self.updated(parseASPDate(updated));
            self.percentComplete(percentComplete);
            self.changed(true);
        };
    };
    
    self.sortField = "updated";
    self.sortAsc = false;
        
    self.add = function (id, description, computerName, userName, started, updated, percentComplete, changed) {
        self.items.unshift(new TaskItem(self, id, description, computerName, userName, parseASPDate(started), parseASPDate(updated), percentComplete, changed));
    };

    self.update = function (id, updated, percentComplete) {
        var object = $.grep(self.items(), function (item) { return item.id == id });
        if (object.length > 0) {
            var index = self.items.indexOf(object[0]);
            self.items()[index].update(updated,percentComplete);

        }
    };
    
    self.getTasks = function () {
        $.get("/api/computer/GetAllTasks", function (items) {
            var newItems = ko.utils.arrayMap(items, function (item) {
                return new TaskItem(self, item.Id, item.Description, item.ComputerName, item.UserName, parseASPDate(item.Started), parseASPDate(item.Updated), item.PercentComplete, false);
            });
            self.items.push.apply(self.items, newItems);
        }, "json");
    };


    self.resize = function () {
        if (self.grid != null)
            self.grid.resizeCanvas();
    };

    self.gridSort = function (columnField, isAsc) {
        var sign = isAsc ? 1 : -1;
        var field = columnField;
            self.items.sort(function (dataRow1, dataRow2) {
                var value1 =  ko.utils.unwrapObservable(dataRow1[field]), value2 =  ko.utils.unwrapObservable(dataRow2[field]);
                var result = (value1 == value2) ? 0 :
                            ((value1 > value2 ? 1 : -1)) * sign;
                return result;
            });
        self.grid.invalidate();
        self.grid.render();
    };

    //columns
    self.columns = [
        {
            id: "TaskID",
            name: "Task ID",
            field: "id",
            minWidth: 50,
            maxWidth: 50,
            sortable: true
        },
        {
            id: "TaskDescription",
            name: "Description",
            field: "description",
            minWidth: 200,
            sortable: true
        },
        {
            id: "TaskComputerName",
            name: "Computer Name",
            field: "computerName",
            sortable: true
        },
        {
            id: "TaskCreator",
            name: "Started By",
            field: "userName",
            sortable: true
        },
        {
            id: "TaskStartTime",
            name: "Started",
            field: "started",
            formatter: Slick.Formatters.Date,
            sortable: true
        },
        {
            id: "TaskUpdateTime",
            name: "last updated",
            field: "updated",
            formatter: Slick.Formatters.Date,
            sortable: true
        },
        {
            id: "TaskPercent",
            name: "Status",
            field: "percentComplete",
            resizable: false,
            formatter: Slick.Formatters.PercentCompleteBar,
            width: 175,
            sortable: true
        }
    ];
    self.options = {
        editable: false,
        enableAddRow: false,
        enableColumnReorder: false,
        enableCellNavigation: true,
        forceFitColumns: true,
        multiColumnSort: false,
        multiSelect: false,
        cellFlashingCssClass: "rowFlash"
    };
}

function SoftwareViewModel() {
    var self = this;
    self.grid = null;
    self.container = null;
    self.sortField = "name";
    self.sortAsc = true;
    self.applicationFilter = ko.observable("");
    self.selected = ko.observable(false);

    function isSelected() {
        
    }

    function SoftwareItem(root, id, name, publisher, version, type, icon) {
        var self = this;

        self.name = name;
        self.publisher = publisher;
        self.version = version;
        self.icon = icon;
        self.type = type;
        self.id = id;

        self.remove = function () {
            root.remove(self);
        };
    };

    self.add = function (id, name, publisher, version, type, icon) {
        self.items.push(new SoftwareItem(self, id, name, publisher, version, type, icon));
    };

    self.resize = function (newGridSize) {
        if (self.grid != null) {
            $(self.container).height(newGridSize);
            self.grid.resizeCanvas();
        }
    };

    self.gridSort = function (columnField, isAsc) {
        var sign = isAsc ? 1 : -1;
        var field = columnField;
        self.items.sort(function (dataRow1, dataRow2) {
            var value1 = dataRow1[field], value2 = dataRow2[field];
            var result = (value1 == value2) ? 0 :
                        ((value1 > value2 ? 1 : -1)) * sign;
            return result;
        });
        self.grid.invalidate();
        self.grid.render();
    };

    self.clear = function () {
        self.items.removeAll();
    };

    self.items = ko.observableArray();

    // Columns
    self.columns = [
      { id: "#", name: "", field: "icon", width: 18, resizable: false, sortable: false, formatter: Slick.Formatters.Icon },
      { id: "installableAppName", name: "Name", field: "name", minWidth: 200, sortable: true },
      { id: "installableAppPublisher", name: "Publisher", field: "publisher", sortable: true },
      { id: "installableAppVersion", name: "Version", field: "version", sortable: true }
    ];


    self.applicationFilterFunction = function (newValue) {
        var filteredData = [];
        if (self.grid == null) {
            return;
        }
        if (newValue != "") {
            ko.utils.arrayForEach(self.items(), function(item) {
                var filter = self.applicationFilter().toLowerCase();
                var name = item["name"].toLowerCase();
                if (filter != "" && name.indexOf(filter) > -1) {
                    filteredData.push(item);
                }
            });
            self.grid.setData(filteredData);
        } else {
            self.grid.setData(ko.utils.unwrapObservable(self.items));
        }
        self.grid.resizeCanvas();
        self.grid.render();
    };

    // Options
    self.options = {
        editable: false,
        enableAddRow: false,
        enableColumnReorder: false,
        enableCellNavigation: true,
        forceFitColumns: true,
        multiColumnSort: false,
        multiSelect: false
    };
}

function InformationViewModel() {
    var self = this;

    function InformationGroup(name) {
        var self = this;
        self.name = name;

        function InformationItem(title, value) {
            var self = this;
            self.title = title;
            self.value = value;
        };

        self.items = ko.observableArray([]);
        self.add = function (title, value) {
            if (value == "")
                value = " ";
            self.items.push(new InformationItem(title, value));
        };
    };

    self.groups = ko.observableArray([]);

    self.add = function (group) {
        self.groups.push(group);
    };

    self.clear = function () {
        self.groups.removeAll();
    };

    self.getInfo = function (resourceID, cVM) {

        $.ajax({
            url: "/api/computer/GetSystemInfo/" + resourceID,
            type: "GET",
            statusCode: {
                200: function (items) {
                    $.each(items, function (idx, item) {
                        var group = new InformationGroup(item.Name);
                        $.each(item.Data, function (idx_, subitem) {
                            group.add(subitem.Title, subitem.Value);
                        });
                        self.add(group);
                    });
                    cVM.loading(false);
                }
            }
        });
    };
   
}

function ComputerViewModel() {
    var self = this;

    self.installedSoftwareViewModel = new SoftwareViewModel();
    self.installableSoftwareViewModel = new SoftwareViewModel();
    self.informationViewModel = new InformationViewModel();
    self.ReportsViewModel = new ReportsViewModel();

    self.name = ko.observable("Nothing Selected");
    self.resourceID = ko.observable("");
    self.loading = ko.observable(false);
    self.deploymentLoading = ko.observable(false);
    self.deploymentSuccess = ko.observable(false);
    self.deploymentFail = ko.observable(false);
    self.appLoading = ko.observable(false);
    self.initialized = ko.observable(false);
    self.selected = ko.observable(false);
    self.updated = ko.observable("");
    self.online = ko.observable(false);
    self.onlineTitle = ko.observable("Offline");

    self.clear = function () {
        //self.installedSoftwareViewModel.clear();
        //self.installableSoftwareViewModel.clear();
        self.informationViewModel.clear();
    };

    self.refresh = function () {
        if (self.name() != "" && self.resourceID() != "") {
            self.init(self.name(), self.resourceID());
        }
    };

    self.deployClick = function() {
        var selectedIndexes = self.installableSoftwareViewModel.grid.getSelectedRows();
        if (selectedIndexes && selectedIndexes[0] != null) {
            var data = self.installableSoftwareViewModel.grid.getData()[selectedIndexes[0]];
            var selectedItem = ko.utils.arrayFirst(self.installableSoftwareViewModel.items(), function(item) {
                return data.id === item.id;
            });
            if (selectedItem)
                self.deployApplication(self.resourceID(), selectedItem.type, selectedItem.id);
        }
    };

    self.deployApplication = function(resourceId, type, id) {
        var data = { "ResourceID": resourceId, "Type": type, "Id": id };
        self.deploymentLoading(true);
        $.ajax({
            url: "/api/computer/DeploySoftware",
            type: "POST",
            dataType: "json",
            data: data,
            statusCode: {
                200: function (returnObj) {
                    if (returnObj.Key) {
                        self.deploymentSuccess(true);
                    } else {
                        self.deploymentFail(true);
                    }
                    setTimeout(function () {
                        self.deploymentSuccess(false);
                        self.deploymentFail(false);
                        self.deploymentLoading(false);
                        self.refresh();
                    }, 2000);
                }
            }
        });
        
    };
    
    self.init = function (name, resourceID) {
        self.clear();
        self.installableSoftwareViewModel.grid.setSelectionModel(new Slick.RowSelectionModel());
        self.installableSoftwareViewModel.grid.setSortColumn("installableAppName", true);
        self.installedSoftwareViewModel.grid.setSortColumn("installableAppName", true);
        self.name(name);
        self.resourceID(resourceID);

        self.installableSoftwareViewModel.applicationFilter("");
        self.installableSoftwareViewModel.applicationFilter.subscribe(function (newValue) {
            self.installableSoftwareViewModel.applicationFilterFunction(newValue);
        });
        
        self.installedSoftwareViewModel.applicationFilter("");
        self.installedSoftwareViewModel.applicationFilter.subscribe(function (newValue) {
            self.installedSoftwareViewModel.applicationFilterFunction(newValue);
        });

        self.loading(true);
        self.appLoading(true);
        $.ajax({
            url: "/api/computer/GetSoftware/" + self.resourceID(),
            type: "GET",
            statusCode: {
                200: function (items) {
                    self.installedSoftwareViewModel.clear();
                    self.installableSoftwareViewModel.clear();
                    if (typeof items.deployed != "undefined" && items.deployed)
                        $.each(items.deployed, function (idx, item) {
                            self.installedSoftwareViewModel.add(item.Id, item.Name, item.Manufacturer, item.Version, item.Type, item.Icon);
                        });
                    if (typeof items.deployable != "undefined" && items.deployable)
                        $.each(items.deployable, function (idx, item) {
                            self.installableSoftwareViewModel.add(item.Id, item.Name, item.Manufacturer, item.Version, item.Type, item.Icon);
                        });
                    self.appLoading(false);
                }
            }
        });
        
        $.ajax({
            url: "/api/computer/GetOnlineStatus/" + self.resourceID(),
            type: "GET",
            statusCode: {
                200: function (items) {
                    if (typeof items != "undefined" && items) {
                        self.online(true);
                        self.onlineTitle("Online");
                    } else {
                        self.online(false);
                        self.onlineTitle("Offline");
                    }
                }
            },
            error: function(jqXHR, exception) {
                self.online(false);
                self.onlineTitle("Offline");
            }
        });

        self.informationViewModel.getInfo(resourceID, self);
        self.updated("Updated " + getCurrentDateString());
    };
}

// This model is bad because of dynatree :(
function treeViewModel() {
    var self = this;

    function treeItem(title, key, folder) {
        var self = this;
        self.title = title;
        self.key = key;
        self.isFolder = folder;
        self.icon = null;
        self.node = null;
        self.children = [];
        if (!folder)
            self.icon = "computer.png";

        self.add = function (title, key, folder) {
            var item = new treeItem(title, key, false);
            var node = self.node.addChild(item);
            item.node = node;
            self.children.push(item);
            return item;
        };
    };

    self.clear = function () {
        self.items.removeAll();
        $(self.tree).dynatree("getRoot").removeChildren();
    };

    self.add = function (title, key) {
        var root = self.tree.dynatree("getRoot");
        var item = new treeItem(title, key, true);
        var node = root.addChild(item);
        item.node = node;
        self.items.push(item);
        return item;
    };

    self.loading = ko.observable(true);
    self.tree = null;
    self.items = ko.observableArray([]);
    self.updated = ko.observable("");

    self.onActivate = function (node) {
        if (!node.data.isFolder) {
            computerVM.selected(true);
            computerVM.init(node.data.title, node.data.key);
        }
        else {
            computerVM.selected(false);
            computerVM.clear();
        }
    };

    self.selectByName = function (name) {
        var match = null;
        $(self.tree).dynatree("getRoot").visit(function (node) {
            if (node.data.title.toUpperCase() === name.toUpperCase()) {
                match = node;
                $(self.tree).dynatree("getRoot").search(name);
                self.onActivate(node);
                $("#compTreeSearch").val(name);
                return false; // stop traversal (if we are only interested in first match)
            }
        });
    }

    self.getTree = function () {
        self.clear();
        self.loading(true);
        
        $.ajax({
            url: "/api/computer/GetTree",
            type: "GET",
            dataType: "json",
            statusCode: {
                200: function (items) {
                    $.each(items, function (idx, item) {
                        var collection = self.add(item.Name, item.Id);
                        $.each(item.Computers, function (idx_, subitem) {
                            collection.add(subitem.Name, subitem.Id);
                        });
                        var cmp = function (a, b) {
                            a = a.data.title.toLowerCase();
                            b = b.data.title.toLowerCase();
                            return a > b ? 1 : a < b ? -1 : 0;
                        };
                        collection.node.sortChildren(cmp, true);
                    });
                    self.updated("Updated " + getCurrentDateString());
                    self.loading(false);
                    var GotoComputer = $.urlParam('computer');
                    if (typeof GotoComputer != "undefined" && GotoComputer) {
                        self.selectByName(GotoComputer);
                    }
                }
            }
        });
    };

}
$(function () {
    // Non-Knockout Event bindings
    $(document).bind('subtabchange', function (e, subtab) {
        subtabchange(subtab);
    });

    // Knockout ViewModel Initialization
    var taskVM = new TaskViewModel();
    computerVM = new ComputerViewModel();
    var treeVM = new treeViewModel();
    var taskHub = $.connection.tasks;
    
    // Custom binding declarations
    ko.bindingHandlers.slickGrid = {
        init: function (element, valueAccessor, allBindingsAccessor, viewModel) {
            var settings = valueAccessor();
            var data = ko.utils.unwrapObservable(settings.data);
            var columns = ko.utils.unwrapObservable(settings.columns);
            var options = viewModel.options;
            var grid = viewModel.grid;
            grid = new Slick.Grid(element, data, columns, options);
            //grid.setSortColumn(viewModel.sortField, viewModel.sortAsc);
            grid.onSort.subscribe(function (e, args) {
                viewModel.sortField = args.sortCol.field;
                viewModel.sortAsc = args.sortAsc;
                viewModel.gridSort(args.sortCol.field, args.sortAsc);
            });
            if (viewModel === computerVM.installableSoftwareViewModel) {
                grid.onSelectedRowsChanged.subscribe(function(e, args) {
                    var selected = grid.getSelectedRows();
                    if (selected && selected[0] != null) {
                        viewModel.selected(true);
                    } else {
                        viewModel.selected(false);
                    }
                });
            }

            viewModel.grid = grid;
            viewModel.container = element;
        },
        update: function (element, valueAccessor, allBindingAccessor, viewModel) {
            var settings = valueAccessor();
            var data = ko.utils.unwrapObservable(settings.data); //just for subscription
            var grid = viewModel.grid;
            grid.invalidate();
            //grid.setData(data);
            if ($(activeSubTab).attr('id') == "applications" || viewModel === taskVM) {
                grid.resizeCanvas(); // NB Very important for when a scrollbar appears
            }
            viewModel.gridSort(viewModel.sortField, viewModel.sortAsc);
            grid.render();
            if (viewModel === taskVM) {
                var updatedRows = $.grep(viewModel.items(), function (row) { return row.changed() == true; });
                for (var row in updatedRows) {
                    var rowItem = updatedRows[row];
                    rowItem.changed(false);
                    grid.flashRowId(rowItem.id, 100);
                }
            }

        }
    };

    // this model is bad, but it has to be due to dynatree
    ko.bindingHandlers.dynatree = {
        init: function (element, valueAccessor, allBindingsAccessor, viewModel) {
            $(element).dynatree({
                onActivate: function (node) {
                    setTimeout(function () { viewModel.onActivate(node); } ,0);
                },
                persist: true,
                imagePath: "/images/"
            });

            viewModel.tree = $(element);
        },
        update: function (element, valueAccessor, allBindingAccessor, viewModel) {

        }
    };

    $.get("/api/computer/GetReportsInfo", function (items) {
        computerVM.ReportsViewModel.siteCode = items["siteCode"];
        computerVM.ReportsViewModel.reportServer = items["reportServer"];
    }, "json");

    computerVM.ReportsViewModel.add("Software - Installed Software", "%2fConfigMgr_{0}%2fAsset+Intelligence%2fSoftware+02E+-+Installed+software+on+a+specific+computer&rs:Command=Render&Name={1}");
    computerVM.ReportsViewModel.add("Software - Inventoried Files", "%2fConfigMgr_{0}%2fSoftware+-+Files%2fAll+inventoried+files+on+a+specific+computer&rs:Command=Render&variable={1}");
    computerVM.ReportsViewModel.add("Software - Recently Executed", "%2fConfigMgr_{0}%2fAsset+Intelligence%2fSoftware+07C+-+Recently+used+executable+programs+on+a+specified+computer&rs:Command=Render&ProductCodeOnly=ALL&ComputerName={1}");
    computerVM.ReportsViewModel.add("AV - Malware List", "%2fConfigMgr_{0}%2fEndpoint+Protection%2fEndpoint+Protection+-+Hidden%2fComputer+malware+list&rs:Command=Render&ComputerName={1}&CollectionID=SMS00001");

    ko.applyBindings(taskVM, $("#taskGridSection")[0]);
    ko.applyBindings(computerVM, $("#computersContent")[0]);
    ko.applyBindings(treeVM, $("#treeContainer")[0]);
    ko.applyBindings(computerVM, $("#initLoading")[0]);
    

    taskVM.grid.setSortColumn("TaskUpdateTime", false);

    taskVM.getTasks();

    taskHub.client.AddEntry = function (item) {
        taskVM.add(item.Id, item.Description, item.ComputerName, item.UserName, item.Started, item.Updated, item.PercentComplete, true);
        var items = taskVM.items();
    };

    taskHub.client.UpdateEntry = function (entryUpdate) {
        taskVM.update(entryUpdate.Id, entryUpdate.Updated, entryUpdate.PercentComplete);
    };

    $.connection.hub.start();

    treeVM.getTree();
    activeTab = $("#computersTab");
    activeSubTab = $("#information");

    // *************
    // Window resizing
    // *************

    $(window).resize(function () {
        //resize containers on window size change
        if ($(window).height() >= minWindowHeight) {
            $('.mainContent').css({
                height: $(window).height() - ($('.mainHeader').height() + $('.mainFooter').height())
            });
        }
        else {
            $('.mainContent').css({
                height: minWindowHeight - ($('.mainHeader').height() + $('.mainFooter').height())
            });
        }

        $('.tree').css({
            height: $('.mainContent').height() - ($('#compTreeSearch').outerHeight() * 2.25 )
        });

        $('.contentDivOuter, .contentDivOuterLoading').css({
            height: $('.mainContent').height() - $('.contentTitle').outerHeight()
        });

        $('#computerApplicationLoading').css({
            width: $('#computersContent').width()
        });
        
        $('#computerLoading').css({
            width: $('#computersContent').width()
        });

        //resize grids on window size change.
        if (taskVM != null)
            taskVM.resize();

        if ($(activeTab).attr('id') == "computersTab" && $(activeSubTab).attr('id') == "applications") {
            var windowHeightDifference = $(window).height() - minWindowHeight >= 0 ? $(window).height() - minWindowHeight : 0;
            var steps = Math.floor(windowHeightDifference / (appGridRowHeight * 2));
            var newGridSize = steps > 0 ? appGridOrigHeight + appGridRowHeight * steps : appGridOrigHeight;

            if (computerVM.installableSoftwareViewModel != null) {
                computerVM.installableSoftwareViewModel.resize(newGridSize);
            }

            if (computerVM.installedSoftwareViewModel != null) {
                computerVM.installedSoftwareViewModel.resize(newGridSize);
            }
        }

    });

    $(window).resize();
    setTimeout(function () { $('#applications').hide(); }, 0);
    //setTimeout(function() { $('.popupOuterDeploy').hide(); }, 0);
    computerVM.initialized(true);
});


// *************
// Non-Knockout Click Events
// *************

// Handle subtab click and event trigger.
$('.submenu a').click(function () {
    $('.submenu a').removeClass('selected');
    $(this).addClass('selected');

    $(this).parents('.contentTab').children('.contentDivOuter').hide();
    var targetSubTab = $('#' + $(this).attr('data-tabID'));
    activeSubTab = targetSubTab;
    targetSubTab.show();
    $(document).trigger('subtabchange', targetSubTab);
});

$("input#compTreeSearch").keyup(function (e) {
    var match = $(this).val();
    if (e && e.which === $.ui.keyCode.ESCAPE || $.trim(match) === "") {
        $("input[name=search]").val("");
        $("#computersTree").dynatree("getRoot").searchClear();
        return;
    }
    // Pass text as filter string (will be matched as substring in the node title)
    $("#computersTree").dynatree("getRoot").search(match);
}).focus();

$('.tool a').click(function () {
    var application = this.name;
    window.location.assign("cmfrontend://" + application + "/" + computerVM.name());
});




// *************
// Custom Event functions
// *************
function subtabchange(subtab) {
    console.log("Changed subtab to: " + $(subtab).attr('id'));
    if ($(subtab).attr('id') == "applications") {
        $(window).resize();
    }
}


// *************
// Helpers
// *************
function parseASPDate(s) {
    if (s) {
        var date = new Date();
        date = new Date(s);
        return date;
    } else {
        return null;
    }
}

function updateNodeRecursively(node, data, includeSelf) {
    if (includeSelf == undefined) includeSelf = true;
    if (includeSelf) node.data = data;
    node.removeChildren();
    if (data.children) {
        for (var i = 0; i < data.children.length; i++) {
            var cnode = node.addChild(data.children[i]);
            updateNodeRecursively(cnode, data.children[i], false);
        }
    }
}

function getCurrentDateString() {
    var date = new Date();
    var day = date.getDate();
    var month = date.getMonth() + 1;
    var year = date.getFullYear();
    var hour = date.getHours() + "";
    if (hour.length == 1)
        hour = "0" + hour;
    var minute = date.getMinutes() + "";
    if (minute.length == 1)
        minute = "0" + minute;
    var second = date.getSeconds() + "";
    if (second.length == 1)
        second = "0" + second;
    return month + "/" + day + "/" + year + " " + hour + ":" + minute + ":" + second;
}

$.urlParam = function (name) {
    var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
    if (results == null) {
        return null;
    }
    else {
        return results[1] || 0;
    }
}