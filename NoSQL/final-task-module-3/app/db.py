import os
import uuid
from datetime import datetime, timezone

from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

MONGOS_URI = os.getenv("MONGOS_URI", "mongodb://mongos:27020/")
DB_NAME = "university"

_client = None


def get_db():
    global _client
    if _client is None:
        _client = MongoClient(MONGOS_URI, serverSelectionTimeoutMS=5000)
        try:
            _client.admin.command("ping")
        except ConnectionFailure:
            _client = None
            raise RuntimeError("Cannot connect to MongoDB.")
    return _client[DB_NAME]


def add_department(db, name: str, code: str) -> str:
    doc = {
        "department_id": str(uuid.uuid4()),
        "name": name,
        "code": code.upper(),
        "created_at": datetime.now(timezone.utc),
    }
    db.departments.insert_one(doc)
    return doc["department_id"]


def list_departments(db) -> list:
    return list(db.departments.find({}, {"_id": 0}))


def get_department_by_id(db, department_id: str) -> dict | None:
    return db.departments.find_one({"department_id": department_id}, {"_id": 0})


def add_student(db, first_name: str, last_name: str, faculty_id: str,
                group_name: str, year: int) -> str:
    doc = {
        "student_id": str(uuid.uuid4()),
        "first_name": first_name,
        "last_name": last_name,
        "faculty_id": faculty_id,
        "group_name": group_name,
        "enrollment_year": year,
        "created_at": datetime.now(timezone.utc),
    }
    db.students.insert_one(doc)
    return doc["student_id"]


def find_students(db, query: dict) -> list:
    return list(db.students.find(query, {"_id": 0}))


def find_students_by_faculty(db, faculty_id: str) -> list:
    return find_students(db, {"faculty_id": faculty_id})


def find_students_by_name(db, last_name: str) -> list:
    return find_students(db, {"last_name": {"$regex": last_name, "$options": "i"}})


def update_student(db, student_id: str, updates: dict) -> int:
    # student_id is the shard key — it cannot be modified
    updates.pop("student_id", None)
    if not updates:
        return 0
    result = db.students.update_one({"student_id": student_id}, {"$set": updates})
    return result.modified_count


def delete_student(db, student_id: str) -> int:
    db.grades.delete_many({"student_id": student_id})
    result = db.students.delete_one({"student_id": student_id})
    return result.deleted_count


def add_course(db, title: str, code: str, credits: int) -> str:
    doc = {
        "course_id": str(uuid.uuid4()),
        "title": title,
        "code": code.upper(),
        "credits": credits,
        "created_at": datetime.now(timezone.utc),
    }
    db.courses.insert_one(doc)
    return doc["course_id"]


def list_courses(db) -> list:
    return list(db.courses.find({}, {"_id": 0}))


def add_grade(db, student_id: str, course_id: str, grade: int, semester: str) -> str:
    if grade not in range(1, 6):
        raise ValueError("Grade must be between 1 and 5")
    doc = {
        "grade_id": str(uuid.uuid4()),
        "student_id": student_id,
        "course_id": course_id,
        "grade": grade,
        "semester": semester,
        "graded_at": datetime.now(timezone.utc),
    }
    db.grades.insert_one(doc)
    return doc["grade_id"]


def get_student_grades(db, student_id: str) -> list:
    pipeline = [
        {"$match": {"student_id": student_id}},
        {"$lookup": {
            "from": "courses",
            "localField": "course_id",
            "foreignField": "course_id",
            "as": "course_info",
        }},
        {"$unwind": {"path": "$course_info", "preserveNullAndEmptyArrays": True}},
        {"$project": {
            "_id": 0,
            "grade_id": 1,
            "course": "$course_info.title",
            "grade": 1,
            "semester": 1,
            "graded_at": 1,
        }},
    ]
    return list(db.grades.aggregate(pipeline))


def update_grade(db, grade_id: str, student_id: str, new_grade: int) -> int:
    if new_grade not in range(1, 6):
        raise ValueError("Grade must be between 1 and 5")
    result = db.grades.update_one(
        {"grade_id": grade_id, "student_id": student_id},
        {"$set": {"grade": new_grade, "graded_at": datetime.now(timezone.utc)}}
    )
    return result.modified_count


def get_shard_distribution(db) -> dict:
    result = {}
    for coll in ["students", "grades", "courses", "departments"]:
        stats = db.command("collStats", coll)
        result[coll] = stats.get("shards", {})
    return result
