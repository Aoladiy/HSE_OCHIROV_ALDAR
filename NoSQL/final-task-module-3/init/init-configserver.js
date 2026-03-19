// init/init-configserver.js
// Инициализация Config Server Replica Set

rs.initiate({
    _id: "configRS",
    configsvr: true,
    members: [{_id: 0, host: "configsvr:27019"}]
});
