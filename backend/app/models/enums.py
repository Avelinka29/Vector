from enum import StrEnum


class UserRole(StrEnum):
    APPLICANT = "applicant"
    EMPLOYER = "employer"
    INSTITUTION = "institution"
    MODERATOR = "moderator"
    ADMIN = "admin"


class UserStatus(StrEnum):
    ACTIVE = "active"
    PENDING = "pending"
    BLOCKED = "blocked"


class OrganizationType(StrEnum):
    EMPLOYER = "employer"
    INSTITUTION = "institution"


class VerificationStatus(StrEnum):
    PENDING = "pending"
    ACTIVE = "active"
    NEEDS_CLARIFICATION = "needs_clarification"
    REJECTED = "rejected"


class MembershipRole(StrEnum):
    OWNER = "owner"
    MANAGER = "manager"
    MEMBER = "member"
