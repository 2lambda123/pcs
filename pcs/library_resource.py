from __future__ import (
    absolute_import,
    division,
    print_function,
    unicode_literals,
)

from pcs import utils
from pcs import error_codes
from pcs.errors import LibraryError
from pcs.errors import ReportItem
from pcs.library_status_info import ClusterState

def cleanup(resource, node, force):
    if not force and not node and not resource:
        operation_threshold = 100
        summary = ClusterState(utils.getClusterStateXml()).summary
        operations = summary.nodes.attrs.count * summary.resources.attrs.count
        if operations > operation_threshold:
            raise LibraryError(ReportItem.error(
                error_codes.RESOURCE_CLEANUP_TOO_TIME_CONSUMING,
                "Cleaning up all resources on all nodes will execute more "
                    + "than {threshold} operations in the cluster, which may "
                    + "negatively impact the responsiveness of the cluster. "
                    + "Consider specifying resource and/or node"
                ,
                info={"threshold": operation_threshold},
                forceable=True
            ))

    cmd = ["crm_resource", "--cleanup"]
    if resource:
        cmd.extend(["--resource", resource])
    if node:
        cmd.extend(["--node", node])

    output, retval = utils.run(cmd)

    if retval != 0:
        if resource is not None:
            text = "Unable to cleanup resource: {resource}\n{crm_output}"
        else:
            text = (
                "Unexpected error occured. 'crm_resource -C' err_code: "
                + "{crm_exitcode}\n{crm_output}"
            )
        raise LibraryError(ReportItem.error(
            error_codes.RESOURCE_CLEANUP_ERROR,
            text,
            info={
                "crm_exitcode": retval,
                "crm_output": output,
                "resource": resource,
                "node": node,
            }
        ))
    return output