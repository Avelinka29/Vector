from sqlalchemy import exists, or_, select

from app.models.catalog import EducationInstitution
from app.models.enums import VerificationStatus
from app.models.institution_workspace import InstitutionProfile
from app.models.organization import Organization


def visible_institution():
    managed = exists(select(InstitutionProfile.organization_id).where(
        InstitutionProfile.catalog_institution_id == EducationInstitution.id
    ).correlate(EducationInstitution))
    approved = exists(select(InstitutionProfile.organization_id).join(
        Organization, Organization.id == InstitutionProfile.organization_id
    ).where(InstitutionProfile.catalog_institution_id == EducationInstitution.id,
            InstitutionProfile.published.is_(True), Organization.status == VerificationStatus.ACTIVE).correlate(EducationInstitution))
    return EducationInstitution.is_active.is_(True) & or_(~managed, approved)
