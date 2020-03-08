var app = angular.module('zalarm', ['ui.bootstrap']);

var AlarmCtrl = function($scope, $modal, $log) {
  $scope.alarms = [{
    alarm_time: 1405153335000,
    content: '爸爸生日'
  }, {
    alarm_time: 1405153335000,
    content: '妈妈生日'
  }, ];

  $scope.alarm = {};

  $scope.open = function() {

    var modalInstance = $modal.open({
      templateUrl: 'detail.html',
      controller: modalAlarmCtrl,
      resolve: {
        alarm: function() {
          return $scope.alarm;
        }
      }
    });

    modalInstance.result.then(function(resultAlarm) {
      $scope.alarms.push(resultAlarm);
    }, function() {
      $log.info('Modal dismissed at: ' + new Date());
    });
  };
};

var modalAlarmCtrl = function($scope, $modalInstance, alarm) {

  $scope.alarm = alarm;

  $scope.ok = function() {
    $modalInstance.close($scope.alarm);
  };

  $scope.cancel = function() {
    $modalInstance.dismiss('cancel');
  };
};
