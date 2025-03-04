// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AppVersionContract {
    // 应用信息结构体
    struct AppInfo {
        string version; // 版本号
        string downloadLink; // 下载链接
        string updateContent; // 更新内容
    }

    // 节点信息结构体 - 精简到只保留批准状态
    struct NodeInfo {
        bool isApproved; // 是否已批准
    }

    // 存储APP信息
    AppInfo private appInfo;

    // 存储已批准的节点网址列表
    string[] private approvedNodeUrls;

    // 存储待审核的节点网址列表
    string[] private pendingNodeUrls;

    // 存储所有节点信息
    mapping(string => NodeInfo) private nodes;

    // 节点网址是否存在
    mapping(string => bool) private nodeUrlExists;

    // 合约拥有者地址
    address private owner;

    // 节点管理员列表
    mapping(address => bool) private nodeManagers;

    // 存储所有管理员地址的数组
    address[] private managerAddresses;

    // 事件：更新应用信息时触发
    event AppInfoUpdated(
        string version,
        string downloadLink,
        string updateContent
    );

    // 事件：添加节点网址时触发
    event NodeUrlAdded(string nodeUrl, bool isApproved);
    // 事件：节点状态更改时触发
    event NodeStatusChanged(string nodeUrl, bool isApproved);

    // 事件：删除节点网址时触发
    event NodeUrlRemoved(string nodeUrl);

    // 事件：添加节点管理员时触发
    event NodeManagerAdded(address indexed manager);

    // 事件：移除节点管理员时触发
    event NodeManagerRemoved(address indexed manager);

    // 构造函数：设置合约拥有者
    constructor() {
        owner = msg.sender;
        nodeManagers[msg.sender] = true; // 合约部署者自动成为管理员
        managerAddresses.push(msg.sender); // 将合约部署者添加到管理员地址数组
    }

    // 修饰符：只有合约拥有者才能调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 修饰符：只有节点管理员才能调用
    modifier onlyNodeManager() {
        require(
            nodeManagers[msg.sender] || msg.sender == owner,
            "Only node manager can call this function"
        );
        _;
    }

    // 更新应用信息
    function updateAppInfo(
        string calldata version,
        string calldata downloadLink,
        string calldata updateContent
    ) external onlyOwner {
        appInfo.version = version;
        appInfo.downloadLink = downloadLink;
        appInfo.updateContent = updateContent;

        emit AppInfoUpdated(version, downloadLink, updateContent);
    }

    // 获取完整应用信息
    function getAppInfo()
        external
        view
        returns (
            string memory version,
            string memory downloadLink,
            string memory updateContent
        )
    {
        return (appInfo.version, appInfo.downloadLink, appInfo.updateContent);
    }

    // 添加节点管理员
    function addNodeManager(address manager) external onlyOwner {
        require(!nodeManagers[manager], "Address is already a node manager");
        nodeManagers[manager] = true;
        managerAddresses.push(manager); // 将新管理员添加到管理员地址数组
        emit NodeManagerAdded(manager);
    }

    // 移除节点管理员
    function removeNodeManager(address manager) external onlyOwner {
        require(nodeManagers[manager], "Address is not a node manager");
        require(manager != owner, "Cannot remove owner from node managers");
        nodeManagers[manager] = false;

        // 从管理员地址数组中移除
        for (uint i = 0; i < managerAddresses.length; i++) {
            if (managerAddresses[i] == manager) {
                if (i < managerAddresses.length - 1) {
                    managerAddresses[i] = managerAddresses[
                        managerAddresses.length - 1
                    ];
                }
                managerAddresses.pop();
                break;
            }
        }

        emit NodeManagerRemoved(manager);
    }

    // 检查是否是节点管理员
    function isNodeManager(address account) external view returns (bool) {
        return nodeManagers[account] || account == owner;
    }

    // 获取所有管理员地址
    function getAllNodeManagers() external view returns (address[] memory) {
        return managerAddresses;
    }

    // 添加节点网址 - 任何人都可以调用
    function addNodeUrl(string calldata nodeUrl) external {
        require(bytes(nodeUrl).length > 0, "Node URL cannot be empty");
        require(!nodeUrlExists[nodeUrl], "Node URL already exists");

        // 如果是管理员，直接批准节点
        bool isApproved = nodeManagers[msg.sender] || msg.sender == owner;

        // 创建新的节点信息
        nodes[nodeUrl] = NodeInfo({isApproved: isApproved});

        // 添加到相应列表
        if (isApproved) {
            approvedNodeUrls.push(nodeUrl);
        } else {
            pendingNodeUrls.push(nodeUrl);
        }

        nodeUrlExists[nodeUrl] = true;

        emit NodeUrlAdded(nodeUrl, isApproved);
    }

    // 批准节点 - 仅管理员可以调用
    function approveNode(string memory nodeUrl) public onlyNodeManager {
        require(nodeUrlExists[nodeUrl], "Node URL does not exist");
        require(!nodes[nodeUrl].isApproved, "Node is already approved");

        // 找到并从待审核列表中移除
        _removeFromArray(pendingNodeUrls, nodeUrl);

        // 添加到已批准列表
        approvedNodeUrls.push(nodeUrl);
        nodes[nodeUrl].isApproved = true;

        emit NodeStatusChanged(nodeUrl, true);
    }

    // 批量批准节点
    function approveNodes(string[] calldata nodeUrls) external onlyNodeManager {
        for (uint i = 0; i < nodeUrls.length; i++) {
            if (nodeUrlExists[nodeUrls[i]] && !nodes[nodeUrls[i]].isApproved) {
                approveNode(nodeUrls[i]);
            }
        }
    }

    // 删除节点网址
    function removeNodeUrl(string calldata nodeUrl) external onlyNodeManager {
        require(nodeUrlExists[nodeUrl], "Node URL does not exist");

        // 从相应列表中移除
        if (nodes[nodeUrl].isApproved) {
            _removeFromArray(approvedNodeUrls, nodeUrl);
        } else {
            _removeFromArray(pendingNodeUrls, nodeUrl);
        }

        // 删除节点信息和记录
        delete nodeUrlExists[nodeUrl];
        delete nodes[nodeUrl];

        emit NodeUrlRemoved(nodeUrl);
    }

    // 批量删除节点 - 仅管理员可以调用
    function removeNodeUrls(
        string[] calldata nodeUrls
    ) external onlyNodeManager {
        for (uint i = 0; i < nodeUrls.length; i++) {
            if (nodeUrlExists[nodeUrls[i]]) {
                string memory nodeUrl = nodeUrls[i];

                // 从相应列表中移除
                if (nodes[nodeUrl].isApproved) {
                    _removeFromArray(approvedNodeUrls, nodeUrl);
                } else {
                    _removeFromArray(pendingNodeUrls, nodeUrl);
                }

                // 删除节点信息和记录
                delete nodeUrlExists[nodeUrl];
                delete nodes[nodeUrl];

                emit NodeUrlRemoved(nodeUrl);
            }
        }
    }

    // 从数组中移除元素的内部函数
    function _removeFromArray(
        string[] storage array,
        string memory value
    ) private {
        for (uint i = 0; i < array.length; i++) {
            if (keccak256(bytes(array[i])) == keccak256(bytes(value))) {
                if (i < array.length - 1) {
                    array[i] = array[array.length - 1];
                }
                array.pop();
                break;
            }
        }
    }

    // 获取节点信息
    function getNodeInfo(
        string calldata nodeUrl
    ) external view returns (bool isApproved) {
        require(nodeUrlExists[nodeUrl], "Node URL does not exist");
        return nodes[nodeUrl].isApproved;
    }

    // 获取已批准的节点网址
    function getApprovedNodeUrls() external view returns (string[] memory) {
        return approvedNodeUrls;
    }

    // 获取待审核的节点网址
    function getPendingNodeUrls() external view returns (string[] memory) {
        return pendingNodeUrls;
    }

    // 获取已批准节点数量
    function getApprovedNodeCount() external view returns (uint) {
        return approvedNodeUrls.length;
    }

    // 获取待审核节点数量
    function getPendingNodeCount() external view returns (uint) {
        return pendingNodeUrls.length;
    }

    // 转让合约所有权
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }

    // 获取合约拥有者
    function getOwner() external view returns (address) {
        return owner;
    }
}
