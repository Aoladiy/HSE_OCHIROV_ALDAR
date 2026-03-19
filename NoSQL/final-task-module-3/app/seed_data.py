import os
import random
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db import get_db

DEPARTMENTS = [
    ("Факультет информатики и вычислительной техники", "FIVT"),
    ("Математический факультет", "MATH"),
    ("Физический факультет", "PHYS"),
    ("Экономический факультет", "ECON"),
    ("Юридический факультет", "LAW"),
]

COURSES = [
    ("Базы данных", "DB101", 4),
    ("Алгоритмы и структуры данных", "ASD201", 5),
    ("Линейная алгебра", "LA101", 4),
    ("Математический анализ", "CALC101", 5),
    ("Физика", "PHYS101", 4),
    ("Экономическая теория", "ECON101", 3),
    ("Право и правоведение", "LAW101", 3),
    ("Операционные системы", "OS201", 4),
    ("Сети и телекоммуникации", "NET301", 4),
    ("Машинное обучение", "ML401", 5),
]

FIRST_NAMES = ["Александр", "Мария", "Иван", "Анна", "Дмитрий",
               "Екатерина", "Сергей", "Ольга", "Андрей", "Наталья",
               "Михаил", "Татьяна", "Алексей", "Юлия", "Николай"]

LAST_NAMES = ["Иванов", "Смирнов", "Кузнецов", "Попов", "Васильев",
              "Петров", "Соколов", "Михайлов", "Новиков", "Фёдоров",
              "Морозов", "Волков", "Алексеев", "Лебедев", "Семёнов"]

SEMESTERS = ["2022-S1", "2022-S2", "2023-S1", "2023-S2", "2024-S1", "2024-S2"]

DEP_CODES = [d[1] for d in DEPARTMENTS]


def seed(n_students: int = 1000):
    db = get_db()
    print(f"Seeding {n_students} students...")

    dep_ids = []
    existing = {d["code"] for d in db.departments.find({}, {"code": 1})}
    for name, code in DEPARTMENTS:
        if code not in existing:
            doc = {
                "department_id": str(uuid.uuid4()),
                "name": name,
                "code": code,
                "created_at": datetime.now(timezone.utc),
            }
            db.departments.insert_one(doc)
            dep_ids.append(doc["department_id"])
        else:
            dep_ids.append(db.departments.find_one({"code": code})["department_id"])
    print(f"  departments: {len(dep_ids)}")

    course_ids = []
    existing_c = {c["code"] for c in db.courses.find({}, {"code": 1})}
    for title, code, credits in COURSES:
        if code not in existing_c:
            doc = {
                "course_id": str(uuid.uuid4()),
                "title": title,
                "code": code,
                "credits": credits,
                "created_at": datetime.now(timezone.utc),
            }
            db.courses.insert_one(doc)
            course_ids.append(doc["course_id"])
        else:
            course_ids.append(db.courses.find_one({"code": code})["course_id"])
    print(f"  courses: {len(course_ids)}")

    students_bulk = []
    grades_bulk = []

    for i in range(n_students):
        sid = str(uuid.uuid4())
        students_bulk.append({
            "student_id": sid,
            "first_name": random.choice(FIRST_NAMES),
            "last_name": random.choice(LAST_NAMES),
            "faculty_id": random.choice(dep_ids),
            "group_name": f"{random.choice(DEP_CODES)}-{random.randint(100, 999)}",
            "enrollment_year": random.randint(2019, 2024),
            "created_at": datetime.now(timezone.utc),
        })
        for course_id in random.sample(course_ids, k=random.randint(3, 6)):
            grades_bulk.append({
                "grade_id": str(uuid.uuid4()),
                "student_id": sid,
                "course_id": course_id,
                "grade": random.randint(2, 5),
                "semester": random.choice(SEMESTERS),
                "graded_at": datetime.now(timezone.utc),
            })

        if (i + 1) % 200 == 0:
            db.students.insert_many(students_bulk)
            db.grades.insert_many(grades_bulk)
            students_bulk.clear()
            grades_bulk.clear()
            print(f"  {i + 1}/{n_students}")

    if students_bulk:
        db.students.insert_many(students_bulk)
    if grades_bulk:
        db.grades.insert_many(grades_bulk)

    print(f"done: {db.students.count_documents({})} students, {db.grades.count_documents({})} grades")


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    seed(n)
