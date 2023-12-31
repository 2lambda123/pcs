from lxml.etree import _Element

from pcs.common.pacemaker.constraint import (
    CibConstraintLocationAttributesDto,
    CibConstraintLocationDto,
    CibConstraintLocationSetDto,
)
from pcs.common.pacemaker.types import CibResourceDiscovery
from pcs.lib.cib.constraint.resource_set import (
    constraint_element_to_resource_set_dto_list,
    is_set_constraint,
)
from pcs.lib.cib.rule import RuleInEffectEval
from pcs.lib.cib.rule.cib_to_dto import rule_element_to_dto
from pcs.lib.cib.tools import role_constructor
from pcs.lib.tools import get_optional_value

TAG_NAME = "rsc_location"


def _element_to_attributes_dto(
    element: _Element, rule_in_effect_eval: RuleInEffectEval
) -> CibConstraintLocationAttributesDto:
    return CibConstraintLocationAttributesDto(
        constraint_id=str(element.attrib["id"]),
        score=element.get("score"),
        node=element.get("node"),
        rules=[
            rule_element_to_dto(rule_in_effect_eval, rule_el)
            for rule_el in element.findall("./rule")
        ],
        lifetime=[
            rule_element_to_dto(rule_in_effect_eval, rule_el)
            for rule_el in element.findall("./lifetime/rule")
        ],
        resource_discovery=get_optional_value(
            CibResourceDiscovery, element.get("resource-discovery")
        ),
    )


def _constraint_el_to_dto(
    element: _Element, rule_in_effect_eval: RuleInEffectEval
) -> CibConstraintLocationDto:
    return CibConstraintLocationDto(
        resource_id=element.get("rsc"),
        resource_pattern=element.get("rsc-pattern"),
        role=get_optional_value(role_constructor, element.get("role")),
        attributes=_element_to_attributes_dto(element, rule_in_effect_eval),
    )


def _set_constraint_el_to_dto(
    element: _Element, rule_in_effect_eval: RuleInEffectEval
) -> CibConstraintLocationSetDto:
    return CibConstraintLocationSetDto(
        resource_sets=constraint_element_to_resource_set_dto_list(element),
        attributes=_element_to_attributes_dto(element, rule_in_effect_eval),
    )


def get_all_as_dtos(
    constraints_el: _Element, rule_in_effect_eval: RuleInEffectEval
) -> tuple[list[CibConstraintLocationDto], list[CibConstraintLocationSetDto]]:
    plain_list: list[CibConstraintLocationDto] = []
    set_list: list[CibConstraintLocationSetDto] = []
    for constraint_el in constraints_el.findall(f"./{TAG_NAME}"):
        if is_set_constraint(constraint_el):
            set_list.append(
                _set_constraint_el_to_dto(constraint_el, rule_in_effect_eval)
            )
        else:
            plain_list.append(
                _constraint_el_to_dto(constraint_el, rule_in_effect_eval)
            )
    return plain_list, set_list
