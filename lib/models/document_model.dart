class DocumentModel {
  final int id;
  final String title;
  final String controlNo;
  final String status;
  final String? fileDeptComment;
  final int? assignedDepartmentId;
  final String updatedAt;
  final String? filePath; 

  DocumentModel({
    required this.id,
    required this.title,
    required this.controlNo,
    required this.status,
    this.fileDeptComment,
    this.assignedDepartmentId,
    required this.updatedAt,
    this.filePath,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      title: json['title'] ?? '',
      controlNo: json['control_no'] ?? '',
      status: json['status'] ?? '',
      fileDeptComment: json['file_dept_comment'],
      assignedDepartmentId: json['assigned_department_id'],
      updatedAt: json['updated_at'] ?? '',
      filePath: json['file_path'], 
    );
  }
}