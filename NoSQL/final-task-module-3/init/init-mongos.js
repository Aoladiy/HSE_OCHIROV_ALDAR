sh.addShard("shard1RS/shard1:27018");
sh.addShard("shard2RS/shard2:27017");
sh.enableSharding("university");

db = db.getSiblingDB("university");

db.createCollection("departments");
db.departments.createIndex({_id: "hashed"});
sh.shardCollection("university.departments", {_id: "hashed"});

db.createCollection("students");
db.students.createIndex({student_id: "hashed"});
sh.shardCollection("university.students", {student_id: "hashed"});
db.students.createIndex({faculty_id: 1});
db.students.createIndex({last_name: 1});
db.students.createIndex({group_name: 1});

db.createCollection("courses");
db.courses.createIndex({course_id: "hashed"});
sh.shardCollection("university.courses", {course_id: "hashed"});

db.createCollection("grades");
db.grades.createIndex({student_id: "hashed"});
sh.shardCollection("university.grades", {student_id: "hashed"});
db.grades.createIndex({student_id: 1, course_id: 1});
db.grades.createIndex({course_id: 1});

print("Sharding configured successfully");
sh.status();
