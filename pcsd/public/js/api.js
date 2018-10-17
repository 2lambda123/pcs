api = {
  reports: {},
  pcsLib: {},
};

api.reports.severityMsgTypeMap = {
  ERROR: "error",
  WARNING: "warning",
  INFO: "info",
};

api.reports.statuses = {
  success: "success",
  error: "error",
};

api.reports.hasOnlyForcibleErrors = function(reportList){
  var foundSomeError = false;
  for(var i in reportList){
    if(!reportList.hasOwnProperty(i)){
      continue;
    }

    var report = reportList[i];
    if (report.severity == "ERROR") {
      if (!report.forceable) {
        return false;
      }
      foundSomeError = true;
    }
  }
  return foundSomeError;
};

api.reports.isForcibleError = function(pcsResult){
  return (
    pcsResult.status === api.reports.statuses.error
    &&
    api.reports.hasOnlyForcibleErrors(pcsResult.report_list)
  );
};

api.reports.toMsgs = function(reportList, msgBuilder){
  return reportList
    .filter(function(report){
      return Object.keys(api.reports.severityMsgTypeMap)
        .includes(report.severity)
      ;
    })
    .map(function(report){
      var msg = report.report_text;
      if (msgBuilder) {
        var buildedMsg = msgBuilder(report);
        if (buildedMsg !== undefined) {
          msg = buildedMsg;
        }
      }
      return {
        type: api.reports.severityMsgTypeMap[report.severity],
        msg: msg + (
          (report.severity === "ERROR" && report.forceable)
            ? " (can be forced)"
            : ""
        ),
      };
    })
  ;
};

api.processSingleStatus = function(resultCode, rejectCode, actionDesc){
  if(resultCode === "success"){
    return promise.resolve();
  }
  var codeMsgMap = {
    "error": "Error during "+actionDesc+"'.",
    "not_supported": tools.string.upperFirst(actionDesc)+"' not supported.",
  };
  return promise.reject(rejectCode, {
    message: codeMsgMap[resultCode] !== undefined
      ? codeMsgMap[resultCode]
      : "Unknown result of "+actionDesc+" (result: '"+resultCode+"')."
    ,
  });
};

api.pcsLib.forcibleLoop = function(apiCall, errGroup, processOptions, force){
  return apiCall(force).then(function(responseString){
    var response = JSON.parse(responseString);

    if (response.status === api.reports.statuses.success) {
      return promise.resolve(response.data);
    }

    if (response.status !== api.reports.statuses.error) {
      return promise.reject(errGroup.PCS_LIB_EXCEPTION, {
        msg: response.status_msg
      });
    }

    var msgs = api.reports.toMsgs(
      response.report_list, processOptions.buildMsg
    );

    if (!api.reports.isForcibleError(response)) {
      return promise.reject(errGroup.PCS_LIB_ERROR, { msgList: msgs });
    }

    if (!processOptions.confirm(msgs)) {
      return promise.reject(errGroup.CONFIRMATION_DENIED);
    }

    return api.pcsLib.forcibleLoop(apiCall, errGroup, processOptions, true);
  });
};

// TODO JSON.parse can fail
api.err = {
  NODES_AUTH_CHECK: {
    FAILED: "NODES_AUTH_CHECK.FAILED",
    WITH_ERR_NODES: "NODES_AUTH_CHECK.WITH_ERR_NODES",
  },
  SEND_KNOWN_HOSTS: {
    FAILED: "SEND_KNOWN_HOSTS.FAILED",
    PCSD_ERROR: "SEND_KNOWN_HOSTS.PCSD_ERROR",
  },
  CLUSTER_SETUP: {
    FAILED: "CLUSTER_SETUP.FAILED",
    PCS_LIB_EXCEPTION: "CLUSTER_SETUP.PCS_LIB_EXCEPTION",
    PCS_LIB_ERROR: "CLUSTER_SETUP.PCS_LIB_ERROR",
    CONFIRMATION_DENIED: "CLUSTER_SETUP.CONFIRMATION_DENIED",
  },
  REMEMBER_CLUSTER: {
    FAILED: "REMEMBER_CLUSTER.FAILED",
  },
  SEND_KNOWN_HOST_TO_CLUSTER: {
    FAILED: "SEND_KNOWN_HOST_TO_CLUSTER.FAILED",
    PCSD_ERROR: "SEND_KNOWN_HOST_TO_CLUSTER.PCSD_ERROR",
  },
  NODE_ADD: {
    FAILED: "NODE_ADD.FAILED",
    PCS_LIB_EXCEPTION: "NODE_ADD.PCS_LIB_EXCEPTION",
    PCS_LIB_ERROR: "NODE_ADD.PCS_LIB_ERROR",
    CONFIRMATION_DENIED: "NODE_ADD.CONFIRMATION_DENIED",
  },
  NODES_REMOVE: {
    FAILED: "NODES_REMOVE.FAILED",
    PCS_LIB_EXCEPTION: "NODES_REMOVE.PCS_LIB_EXCEPTION",
    PCS_LIB_ERROR: "NODES_REMOVE.PCS_LIB_ERROR",
    CONFIRMATION_DENIED: "NODES_REMOVE.CONFIRMATION_DENIED",
  },
  CLUSTER_START: {
    FAILED: "CLUSTER_START.FAILED",
  },
  CLUSTER_DESTROY: {
    FAILED: "CLUSTER_DESTROY.FAILED",
  }
};

api.tools = {};

api.tools.forceFlags = function(force){
  return force ? ["FORCE"] : [];
};

api.checkAuthAgainstNodes = function(nodesNames){
  return promise.get(
    "/manage/check_auth_against_nodes",
    {"node_list": nodesNames},
    api.err.NODES_AUTH_CHECK.FAILED,

  ).then(function(nodesAuthStatusResponse){
    var nodesAuthStatus = JSON.parse(nodesAuthStatusResponse);
    var status = {
      ok: [],
      noAuth: [],
      noConnect: [],
    };

    for (var name in nodesAuthStatus) {
      if( ! nodesAuthStatus.hasOwnProperty(name)){
        continue;
      }
      switch(nodesAuthStatus[name]){
        case "Online": status.ok.push(name); break;
        case "Unable to authenticate": status.noAuth.push(name); break;
        default: status.noConnect.push(name); break;
      }
    }

    return promise.resolve(status);
  });
};

api.clusterSetup = function(submitData, processOptions){
  var setupData = submitData.setupData;
  var setupCoordinatingNode = submitData.setupCoordinatingNode;

  var data = {
    cluster_name: setupData.clusterName,
    nodes: setupData.nodesNames.map(function(nodeName){
      return {name: nodeName};
    }),
    transport_type: "knet",
    transport_options: {},
    link_list: [],
    compression_options: {},
    crypto_options: {},
    totem_options: {},
    quorum_options: {},
  };

  var apiCall = function(force){
    data.force_flags = api.tools.forceFlags(force);
    return promise.post(
      "/manage/cluster-setup",
      {
        target_node: setupCoordinatingNode,
        setup_data: JSON.stringify(data),
      },
      api.err.CLUSTER_SETUP.FAILED,
    );
  };

  return api.pcsLib.forcibleLoop(
    apiCall,
    api.err.CLUSTER_SETUP,
    processOptions
  );
};

api.sendKnownHostsToNode = function(setupCoordinatingNode, nodesNames){
  return promise.post(
    "/manage/send-known-hosts-to-node",
    {
      target_node: setupCoordinatingNode,
      "node_names[]": nodesNames,
    },
    api.err.SEND_KNOWN_HOSTS.FAILED,

  ).then(function(response){
    return api.processSingleStatus(
      response,
      api.err.SEND_KNOWN_HOSTS.PCSD_ERROR,
      "sharing authentication with node '"+setupCoordinatingNode+"'",
    );
  });
};

api.rememberCluster = function(clusterName, nodesNames){
  return promise.post(
    "/manage/remember-cluster",
    {
      cluster_name: clusterName,
      "nodes[]": nodesNames,
    },
    api.err.REMEMBER_CLUSTER.FAILED,
  );
};

api.sendKnownHostsToCluster = function(clusterName, nodesNames){
  return promise.post(
    get_cluster_remote_url(clusterName)+"send-known-hosts",
    {
      "node_names[]": nodesNames,
    },
    api.err.SEND_KNOWN_HOST_TO_CLUSTER.FAILED,
  ).then(function(response){
    return api.processSingleStatus(
      response,
      api.err.SEND_KNOWN_HOST_TO_CLUSTER.PCSD_ERROR,
      "sharing authentication for nodes '"+nodesNames.join("', '")
        +"' with cluster '"+clusterName+"'"
      ,
    );
  });
};

api.clusterNodeAdd = function(submitData, processOptions){
  var nodeAddData = submitData.nodeAddData;

  var node = {name: nodeAddData.nodeName};
  if (nodeAddData.nodeAddresses.length > 0) {
    node.addrs = nodeAddData.nodeAddresses;
  }
  if (nodeAddData.sbd !== undefined) {
    node.watchdog = nodeAddData.sbd.watchdog;
    node.devices = nodeAddData.sbd.devices;
  }

  var data = {
    nodes: [node],
    wait: false,
    start: false, // don't slow it down; start will be considered aftermath
    enable: true,
    no_watchdog_validation: nodeAddData.sbd !== undefined
      ? nodeAddData.sbd.noWatchdogValidation 
      : false
    ,
  };

  var apiCall = function(force){
    data.force_flags = api.tools.forceFlags(force);
    return promise.post(
      get_cluster_remote_url(submitData.clusterName)+"cluster_add_nodes",
      {data_json: JSON.stringify(data)},
      api.err.NODE_ADD.FAILED
    );
  };

  return api.pcsLib.forcibleLoop(apiCall, api.err.NODE_ADD, processOptions);
};

api.clusterNodeRemove = function(submitData, processOptions){
  var data = { node_list: submitData.nodeNameList };
  var apiCall = function(force){
    data.force_flags = api.tools.forceFlags(force);
    return promise.post(
      get_cluster_remote_url(submitData.clusterName)+"cluster_remove_nodes",
      {data_json: JSON.stringify(data)},
      api.err.NODES_REMOVE.FAILED,
      {
        timeout: 60000,
      }
    );
  };
  return api.pcsLib.forcibleLoop(apiCall, api.err.NODES_REMOVE, processOptions);
};

api.clusterStart = function(clusterName, nodeName){
  return promise.post(
    get_cluster_remote_url(clusterName)+"cluster_start",
    {name: nodeName},
    api.err.CLUSTER_START.FAILED,
  );
};

api.clusterDestroy = function(clusterName){
  return promise.post(
    get_cluster_remote_url(clusterName)+"cluster_destroy",
    { all: 1 },
    api.err.CLUSTER_DESTROY.FAILED,
  );
};
