import 'package:Oak/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  String _id;
  String _title;
  String _description;
  String _coursePrefix;
  String _courseNumber;
  String _school;
  List<String> _imageIds; // This is a list of firebase download Urls
  int _rating;
  
  Note(
    this._id,
    this._title, 
    this._description, 
    this._courseNumber, 
    this._coursePrefix, 
    this._school,
    this._imageIds,
    this._rating
  );

  String get id => _id;
  String get title => _title;
  String get description => _description;
  String get coursePrefix => _coursePrefix;
  String get courseNumber => _courseNumber;
  String get school => _school;
  List<String> get imageIds => _imageIds;
  int get rating => _rating;

  Note.map(dynamic obj) {
    this._id = obj['id'];
    this._title = obj['title'];
    this._description = obj['description'];
    this._courseNumber = obj['course_number'];
    this._coursePrefix = obj['course_prefix'];
    this._school = obj['school'];
    this._imageIds = obj['image_ids'].cast<String>();
    this._rating = obj['rating'];
  }

  Note.fromSnapshot(Map<String, dynamic> snapshot) {
    _id = snapshot['id'];
    _title = snapshot['title'];
    _description = snapshot['description'];
    _courseNumber = snapshot['course_number'];
    _coursePrefix = snapshot['course_prefix'];
    _school = snapshot['school'];
    _imageIds =snapshot['images_ids'];
    _rating = snapshot['rating'];
  }

  toObject() {
    return {
      'id':_id,
      'title':_title,
      'description':_description,
      'course_number':_courseNumber,
      'course_prefix':_coursePrefix,
      'school':_school,
      'image_ids': _imageIds,
      'rating': _rating
    };
  }

}