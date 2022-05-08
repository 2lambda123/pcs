from typing import (
    Iterable,
    Set,
)

from pcs.common.reports import (
    ReportItem,
    ReportItemDto,
    ReportItemSeverity,
    ReportProcessor,
)
from pcs.common.reports.types import SeverityLevel

from .messages import report_item_msg_from_dto
from .output import (
    error,
    prepare_force_text,
    warn,
)


class ReportProcessorToConsole(ReportProcessor):
    def __init__(self, debug: bool = False) -> None:
        super().__init__()
        self.debug = debug
        self._ignore_severities = self._get_ignored_severities([])

    def _do_report(self, report_item: ReportItem) -> None:
        report_item_dto = report_item.to_dto()
        if report_item_dto.severity.level not in self._ignore_severities:
            print_report(report_item_dto)

    def _get_ignored_severities(
        self, suppressed_severity_list: Iterable[SeverityLevel]
    ) -> Set[SeverityLevel]:
        ignore_severities = set(suppressed_severity_list)
        if self.debug:
            ignore_severities -= {ReportItemSeverity.DEBUG}
        else:
            ignore_severities |= {ReportItemSeverity.DEBUG}
        return ignore_severities

    def suppress_reports_of_severity(
        self, severity_list: Iterable[SeverityLevel]
    ) -> None:
        self._ignore_severities = self._get_ignored_severities(severity_list)


def print_report(report_item_dto: ReportItemDto) -> None:
    msg = report_item_msg_from_dto(report_item_dto.message).message
    if not msg:
        return
    if report_item_dto.context:
        msg = f"{report_item_dto.context.node}: {msg}"
    severity = report_item_dto.severity.level

    if severity == ReportItemSeverity.ERROR:
        error(
            "{msg}{force}".format(
                msg=msg,
                force=prepare_force_text(
                    ReportItemSeverity.from_dto(report_item_dto.severity)
                ),
            )
        )
    elif severity == ReportItemSeverity.WARNING:
        warn(msg)
    else:
        print(msg, flush=True)
