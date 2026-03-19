// init/init-shard2.js
// Инициализация Shard 2 Replica Set

rs.initiate({
    _id: "shard2RS",
    members: [{_id: 0, host: "shard2:27017"}]
});
