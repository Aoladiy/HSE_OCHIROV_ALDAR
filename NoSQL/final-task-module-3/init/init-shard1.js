// init/init-shard1.js
// Инициализация Shard 1 Replica Set

rs.initiate({
    _id: "shard1RS",
    members: [{_id: 0, host: "shard1:27018"}]
});
