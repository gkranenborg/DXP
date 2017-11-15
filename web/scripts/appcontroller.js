var ibpmApp = angular.module("ibpmApp",[]);

   ibpmApp.controller('IbpmCtrl',['$scope', '$http', function ($scope, $http) {    
    
      $scope.system = {"database":"Stopped","jbossibpm":"Stopped","elasticsearch":"Stopped","kibana":"Stopped"};
      $scope.chatname = "yourname";
      $scope.baseurl = window.location.protocol + "//" + window.location.hostname + ":";
	  $scope.appversions = [];
	  $scope.appinstall = [];
    
      $scope.getclassname = function(val) {
         if (val == "Running") {
            return "Running";
         } 
         return "Stopped";
      };
    
      function GetSystemStatusBackground() {
         GetSystemStatus();
         $scope.$apply();
      };
    
      function GetSystemStatus() {
         $http.get('scripts/STATUSresult.json').success(function(data) {
            $scope.system = data;
         });
         $scope.CurrentDate = new Date();
      };
        
      $http.get('scripts/version.json').success(function(data) {
         $scope.version = data;
      });
	  
	  $http.get('scripts/appversions.json').success(function(data) {
         $scope.appversions = data;
      });
	  
	  $http.get('scripts/appinstall.json').success(function(data) {
         $scope.appinstall = data;
      });
    
      GetSystemStatus();
      var GetSystemStatusStart = setInterval(GetSystemStatusBackground, 150000);

   }]);