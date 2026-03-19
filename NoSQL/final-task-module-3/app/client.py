import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from db import (
    get_db, add_department, list_departments,
    add_student, find_students_by_faculty, find_students_by_name,
    update_student, delete_student,
    add_course, list_courses,
    add_grade, get_student_grades, update_grade,
    get_shard_distribution,
)


def sep():
    print("-" * 55)


def header(title: str):
    sep()
    print(f"  {title}")
    sep()


def pause():
    input("\n[Enter] - вернуться в меню...")


MAIN_MENU = """
  University DB
  -------------
  1. Факультеты
  2. Студенты
  3. Курсы
  4. Оценки
  5. Распределение по шардам
  0. Выход
"""


def menu_departments(db):
    while True:
        header("ФАКУЛЬТЕТЫ")
        print("  1. Список")
        print("  2. Добавить")
        print("  0. Назад")
        choice = input("\n> ").strip()

        if choice == "1":
            deps = list_departments(db)
            if not deps:
                print("Нет факультетов.")
            for d in deps:
                print(f"  [{d['code']}] {d['name']}  id={d['department_id']}")
            pause()

        elif choice == "2":
            name = input("Название: ").strip()
            code = input("Код (например, CS): ").strip()
            dep_id = add_department(db, name, code)
            print(f"Добавлено. ID: {dep_id}")
            pause()

        elif choice == "0":
            break


def menu_students(db):
    while True:
        header("СТУДЕНТЫ")
        print("  1. Найти по фамилии")
        print("  2. Найти по факультету")
        print("  3. Добавить")
        print("  4. Обновить")
        print("  5. Удалить")
        print("  0. Назад")
        choice = input("\n> ").strip()

        if choice == "1":
            last = input("Фамилия (или часть): ").strip()
            _print_students(find_students_by_name(db, last))
            pause()

        elif choice == "2":
            deps = list_departments(db)
            if not deps:
                print("Сначала добавьте факультеты.")
                pause()
                continue
            for d in deps:
                print(f"  [{d['code']}] {d['name']}  id={d['department_id']}")
            fid = input("ID факультета: ").strip()
            _print_students(find_students_by_faculty(db, fid))
            pause()

        elif choice == "3":
            first = input("Имя: ").strip()
            last = input("Фамилия: ").strip()
            for d in list_departments(db):
                print(f"  [{d['code']}] {d['name']}  id={d['department_id']}")
            fid = input("ID факультета: ").strip()
            group = input("Группа: ").strip()
            year = int(input("Год поступления: ").strip())
            sid = add_student(db, first, last, fid, group, year)
            print(f"Добавлено. ID: {sid}")
            pause()

        elif choice == "4":
            sid = input("ID студента: ").strip()
            group = input("Новая группа (Enter - пропустить): ").strip()
            year_s = input("Новый год (Enter - пропустить): ").strip()
            updates = {}
            if group:
                updates["group_name"] = group
            if year_s:
                updates["enrollment_year"] = int(year_s)
            if updates:
                print(f"Обновлено: {update_student(db, sid, updates)}")
            else:
                print("Нет изменений.")
            pause()

        elif choice == "5":
            sid = input("ID студента: ").strip()
            if input(f"Удалить {sid}? (y/N): ").strip().lower() == "y":
                print(f"Удалено: {delete_student(db, sid)}")
            pause()

        elif choice == "0":
            break


def _print_students(students):
    if not students:
        print("Не найдено.")
        return
    for s in students:
        print(f"  {s['last_name']} {s['first_name']}  "
              f"группа={s['group_name']}  год={s['enrollment_year']}  "
              f"id={s['student_id']}")


def menu_courses(db):
    while True:
        header("КУРСЫ")
        print("  1. Список")
        print("  2. Добавить")
        print("  0. Назад")
        choice = input("\n> ").strip()

        if choice == "1":
            courses = list_courses(db)
            if not courses:
                print("Нет курсов.")
            for c in courses:
                print(f"  [{c['code']}] {c['title']}  кредиты={c['credits']}  id={c['course_id']}")
            pause()

        elif choice == "2":
            title = input("Название: ").strip()
            code = input("Код (например, MATH101): ").strip()
            credits = int(input("Кол-во кредитов: ").strip())
            print(f"Добавлено. ID: {add_course(db, title, code, credits)}")
            pause()

        elif choice == "0":
            break


def menu_grades(db):
    while True:
        header("ОЦЕНКИ")
        print("  1. Оценки студента")
        print("  2. Выставить оценку")
        print("  3. Изменить оценку")
        print("  0. Назад")
        choice = input("\n> ").strip()

        if choice == "1":
            sid = input("ID студента: ").strip()
            grades = get_student_grades(db, sid)
            if not grades:
                print("Оценок нет.")
            for g in grades:
                print(f"  {g.get('course', 'N/A')}  оценка={g['grade']}  семестр={g['semester']}")
            pause()

        elif choice == "2":
            sid = input("ID студента: ").strip()
            for c in list_courses(db):
                print(f"  [{c['code']}] {c['title']}  id={c['course_id']}")
            cid = input("ID курса: ").strip()
            grade = int(input("Оценка (1-5): ").strip())
            semester = input("Семестр (например, 2024-S1): ").strip()
            print(f"Добавлено. ID: {add_grade(db, sid, cid, grade, semester)}")
            pause()

        elif choice == "3":
            sid = input("ID студента: ").strip()
            grades = get_student_grades(db, sid)
            if not grades:
                print("Оценок нет.")
                pause()
                continue
            for i, g in enumerate(grades):
                print(
                    f"  {i + 1}. {g.get('course', 'N/A')}  оценка={g['grade']}  семестр={g['semester']}  id={g.get('grade_id', '?')}")
            gid = input("ID оценки: ").strip()
            new_grade = int(input("Новая оценка (1-5): ").strip())
            print(f"Обновлено: {update_grade(db, gid, sid, new_grade)}")
            pause()

        elif choice == "0":
            break


def show_shard_stats(db):
    header("РАСПРЕДЕЛЕНИЕ ПО ШАРДАМ")
    for coll, shards in get_shard_distribution(db).items():
        print(f"\n  {coll}")
        if not shards:
            print("    нет данных")
            continue
        total = sum(s.get("count", 0) for s in shards.values())
        for shard_name, stats in shards.items():
            count = stats.get("count", 0)
            pct = (count / total * 100) if total else 0
            bar = "#" * int(pct / 5)
            print(f"    {shard_name:<20} {count:>7} docs  {pct:5.1f}%  {bar}")
    pause()


def main():
    print("University Sharded Database")
    try:
        db = get_db()
    except RuntimeError as e:
        print(e)
        sys.exit(1)

    while True:
        print(MAIN_MENU)
        choice = input("> ").strip()

        if choice == "1":
            menu_departments(db)
        elif choice == "2":
            menu_students(db)
        elif choice == "3":
            menu_courses(db)
        elif choice == "4":
            menu_grades(db)
        elif choice == "5":
            show_shard_stats(db)
        elif choice == "0":
            break
        else:
            print("Неверный выбор.")


if __name__ == "__main__":
    main()
