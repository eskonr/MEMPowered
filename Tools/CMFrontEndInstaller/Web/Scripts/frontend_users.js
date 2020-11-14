function UserComputersViewModel() {
    var self = this;
    self.grid = null;

    self.items = ko.observableArray([]);
    self.username = ko.observable("");

    function UserComputer(root, ComputerName, ModelName, Manufacturer, SerialNumber) {
        var self = this;

        self.ComputerName = ComputerName;
        self.ModelName = ModelName;
        self.Manufacturer = Manufacturer;
        self.SerialNumber = SerialNumber;

        self.remove = function () {
            root.remove(self);
        };
    };

    self.sortField = "ComputerName";
    self.sortAsc = false;

    self.add = function (id, ComputerName, ModelName, Manufacturer, SerialNumber) {
        self.items.unshift(new UserComputer(self, ComputerName, ModelName, Manufacturer, SerialNumber));
    };

    self.getComputers = function (username) {
        $.ajax({
            url: "/api/user/GetComputers/" + username,
            type: "GET",
            statusCode: {
                200: function (items) {
                    self.clear();
                    if (typeof items != "undefined" && items) {
                        var newItems = ko.utils.arrayMap(items, function (item) {
                            return new UserComputer(self, item.ComputerName, item.ModelName, item.Manufacturer, item.SerialNumber, false);
                        });
                        self.items.push.apply(self.items, newItems);
                    }
                }
            }
        });
    };


    self.resize = function () {
        if (self.grid != null)
            self.grid.resizeCanvas();
    };

    self.gridSort = function (columnField, isAsc) {
        var sign = isAsc ? 1 : -1;
        var field = columnField;
        self.items.sort(function (dataRow1, dataRow2) {
            var value1 = ko.utils.unwrapObservable(dataRow1[field]), value2 = ko.utils.unwrapObservable(dataRow2[field]);
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

    self.userSearch = function () {
        self.getComputers(self.username());
    }

    //columns
    self.columns = [
        {
            id: "ComputerName",
            name: "Computer Name",
            field: "ComputerName",
            minWidth: 200,
            sortable: true,
            formatter: Slick.Formatters.Link,
        },
        {
            id: "Manufacturer",
            name: "Manufacturer",
            field: "Manufacturer",
            sortable: true
        },
        {
            id: "ModelName",
            name: "Model Name",
            field: "ModelName",
            sortable: true
        },
        {
            id: "SerialNumber",
            name: "Serial Number",
            field: "SerialNumber",
            sortable: true
        },
    ];
    self.options = {
        editable: false,
        enableAddRow: false,
        enableColumnReorder: false,
        enableCellNavigation: true,
        forceFitColumns: true,
        multiColumnSort: false,
        multiSelect: false,
        autoHeight: true
    };
}

$(function () {
    // Non-Knockout Event bindings
    $(document).bind('subtabchange', function (e, subtab) {
        subtabchange(subtab);
    });

    // Knockout ViewModel Initialization
    var UserComputersVM = new UserComputersViewModel();
    
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
            if (viewModel === UserComputersViewModel) {
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
            if (viewModel === UserComputersVM) {
                grid.resizeCanvas(); // NB Very important for when a scrollbar appears
            }
            viewModel.gridSort(viewModel.sortField, viewModel.sortAsc);
            grid.render();

        }
    };

    ko.bindingHandlers.enterkey = {
        init: function (element, valueAccessor, allBindings, viewModel) {
            var callback = valueAccessor();
            $(element).keypress(function (event) {
                var keyCode = (event.which ? event.which : event.keyCode);
                if (keyCode === 13) {
                    callback.call(viewModel);
                    return false;
                }
                return true;
            });
        }
    };

    ko.applyBindings(UserComputersVM);

    $(window).resize(function () {
        if (UserComputersVM != null)
            UserComputersVM.resize();
    });
})

