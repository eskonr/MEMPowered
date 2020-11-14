/***
 * Contains basic SlickGrid formatters.
 * @module Formatters
 * @namespace Slick
 */

(function ($) {
  // register namespace
  $.extend(true, window, {
    "Slick": {
      "Formatters": {
        "PercentComplete": PercentCompleteFormatter,
        "PercentCompleteBar": PercentCompleteBarFormatter,
        "YesNo": YesNoFormatter,
        "Checkmark": CheckmarkFormatter,
        "Date": DateFormatter,
        "Icon": IconFormater,
        "Link": linkFormatter
      }
    }
  });

  function PercentCompleteFormatter(row, cell, value, columnDef, dataContext) {
    if (value == null || value === "") {
      return "-";
    } else if (value < 50) {
      return "<span style='color:red;font-weight:bold;'>" + value + "%</span>";
    } else {
      return "<span style='color:green'>" + value + "%</span>";
    }
  }

  function PercentCompleteBarFormatter(row, cell, value, columnDef, dataContext) {
    var value = ko.utils.unwrapObservable(value);
    if (value == null || value === "") {
      return "";
    }

    var color = "black";
    var text = "";
    
    if (value == 0) {
        text = "Initializing"
    } else if (value == 25) {
        text = "Setting Membership";
    } else if (value == 50) {
        text = "Refreshing Policy";
    } else if (value == 75) {
        color = "#3eb500";
        text = "Waiting for client";
    } else if (value == 100) {
        color = "green";
        text = "Deployment Complete";
    } else {
      color = "green";
    }
      
    if (value == -1) {
        return "<span style='color:red;font-weight:bold;'>Deployment Failed</span>";
    }

    return "<span style='color:" + color + ";font-weight:bold;'>" + text + "</span>";
  }

  function YesNoFormatter(row, cell, value, columnDef, dataContext) {
    return value ? "Yes" : "No";
  }

  function CheckmarkFormatter(row, cell, value, columnDef, dataContext) {
    return value ? "<img src='../images/tick.png'>" : "";
  }

  function DateFormatter(row, cell, value, columnDef, dataContext) {
      var value = ko.utils.unwrapObservable(value);
      return (value.getMonth() + 1) + "/" + value.getDate() + "/" + value.getFullYear() + " " + (value.getHours() < 10 ? '0' : '') + value.getHours() + ":" + (value.getMinutes() < 10 ? '0' : '') + value.getMinutes() + ":" + (value.getSeconds() < 10 ? '0' : '') + value.getSeconds();
  }

  function IconFormater(row, cell, value, columnDef, dataContext) {
      var defIcon = "";
      if (dataContext.type == "application")
          defIcon = "/Images/icons/application.png";
      else
          defIcon = "/Images/icons/package.png";
      return value ? "<img class='application-icon' src='" + value + "' width=16 height=16 />" : "<img class='application-icon' src='" + defIcon + "' width=16 height=16 />";
  }

  function linkFormatter(row, cell, value, columnDef, dataContext) {
      return '<a href="/?computer=' + value + '">' + value + '</a>';
  }
})(jQuery);