import 'dart:async';
import './StorageServices.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/note.dart';
import '../model/user.dart';
import '../auth/Authenticator.dart';


final dBReference = Firestore.instance;
final usersReference  = dBReference.collection('users');
final notesReference = dBReference.collection('notes');
final auth = Authenticator();

class DbServices {

  // Auth services
  static Future<User> getUserFromFBUser(FirebaseUser fbUser) async {
    String uid = fbUser.uid;
    QuerySnapshot query = await usersReference.where('uid', isEqualTo: uid).getDocuments();
    if (query.documents.length != 0) {
      var data = query.documents[0].data;
      // get notes from DB for user
      var formattedData = await _convertRefsToNotes(data);
      return User.map(formattedData);
    } else {
      print('user with this account does not exist');
      return null;
    }
  }

  static Future<User> createUserFromFBUser(FirebaseUser fbUser) async {
    User newUser = _buildDbUser(fbUser);
    await addNewUserInDB(newUser);
    return getUserFromFBUser(fbUser);
  }

  // User CRUD using normal user model
  static Future<void> addNewUserInDB(User user) async {
    await usersReference.document(user.uid).setData(user.toObject());
    final DocumentReference userRef = usersReference.document(user.uid);
    await Firestore.instance.runTransaction((Transaction tx) async {
      DocumentSnapshot postSnapshot = await tx.get(userRef);
      if (postSnapshot.exists) {
        await tx.set(userRef, user.toObject());
      }
    });
  }

  static Future<void> updateCurrentUserInDB(User user) async {
    user = _convertNotesToRefs(user); // exchange the note class for a reference that firebase understands
    await usersReference.document(user.uid).updateData(user.toObject());
    final DocumentReference userRef = usersReference.document(user.uid);
    await Firestore.instance.runTransaction((Transaction tx) async {
      DocumentSnapshot postSnapshot = await tx.get(userRef);
      if (postSnapshot.exists) {
        await tx.update(userRef, user.toObject());
      }
    });
  }

  static Future<void> readCurrentUserInDB(String uid) async {
    var query = await usersReference.document(uid).get();
    if (query.data != null) {
      var data = query.data;
      var formattedData = await _convertRefsToNotes(data);
      
      return User.map(formattedData);
    }
  }

  static void deleteUserInDB(User user) async {
    String uid = user.uid;
    await usersReference.document(uid).delete();
    final DocumentReference userRef = usersReference.document(user.uid);
    await Firestore.instance.runTransaction((Transaction tx) async {
      DocumentSnapshot postSnapshot = await tx.get(userRef);
      if (postSnapshot.exists) {
        await tx.delete(userRef);
      }
    });
  }

  // Note CRUD
  static Future<void> addNoteSetInDB(Note note, List<String> filePaths) async {
    // Passed a incomplete note, needs list of documentReferences
    // 1. create the note
    // 2. call the storage file to upload the notes, this will update the note
    // 3. Update the user with the new note 
    
    await notesReference.document(note.id).setData(note.toObject());
    await StorageServices.uploadImageSet(filePaths, note);
    User current = await auth.getCurrentUser();
    // add the note to the current user
    var userObj = current.toObject();
    userObj['saved_notes'].add(note);
    await updateCurrentUserInDB(current);
    
  }

  static Future<void> updateNoteSetInDB(Note note) async {
    await notesReference.document(note.id).updateData(note.toObject());
    
  }

  static Future<void> readNoteSetInDB(Note note) async {
    DocumentSnapshot noteRef = await notesReference.document(note.id).get();
    return _convertRefsToNotes(noteRef.data);
  }

  static Future<void> deleteNoteSetInDB(Note note) {
    notesReference.document(note.id).delete();
    
  }

  static _transact() {

  }

  static getAllNotesInDB({ int max }) async {
    QuerySnapshot querySnapshot = await notesReference.getDocuments();
    List<DocumentSnapshot> docs = querySnapshot.documents;
    List<Note> toreturn = [];
    if (max != null) {
      for (int i = 0; i < max; i ++) {
        DocumentSnapshot doc = docs[i];
        toreturn.add(new Note.map(doc.data));
      }
    } else {
      // get all the notes in the database
      for (DocumentSnapshot doc in docs ) {
        toreturn.add(new Note.map(doc.data));
      }
      return toreturn;
    }
  }

  static _buildDbUser(FirebaseUser fbUser) {
    return new User(
      fbUser.uid,
      fbUser.displayName,
      fbUser.email,
      0,
      [],
      [] 
    );
  }

  static getNotes(int limit, Map<int, String> filters, String category) async {
    List<Note> toreturn = [];
    category = category.toLowerCase();
    QuerySnapshot qs = await notesReference.limit(2500).getDocuments();
    List<DocumentSnapshot> docs = qs.documents;
    for (int i in filters.keys) {
      String queryString = filters[i].toLowerCase();
      for (DocumentSnapshot ref in docs) {
        if (toreturn.length == limit) break; // break if limit reached

        
        var data;
        if (category == 'school' || category == 'title') {
          data = ref.data[category].toString().toLowerCase();
          RegExp re = new RegExp(queryString);
          if (re.hasMatch(data)) {
            toreturn.add(Note.map(ref.data));
          }
        } else if (category == 'course') {
          data = { 
            'p': ref.data['course_prefix'].toString().toLowerCase(),
            'n': ref.data['course_number'] .toString().toLowerCase() 
          };
          // match the course prefix or number
          RegExp p = new RegExp(data['p']);
          RegExp n = new RegExp(data['n']);
          // TODO: Change this to regex for extra bonus
          if (n.hasMatch(queryString) && p.hasMatch(queryString)) {
            toreturn.add(Note.map(ref.data));
          }
        }
      }
    }
    return toreturn;
  }

  static loadNotes() {

  }

  static _convertRefsToNotes(Map<String, dynamic> data) async {
    List<DocumentReference> createdNotesRefs = data['created_notes'].cast<DocumentReference>();
    List<DocumentReference> savedNotesRefs = data['saved_notes'].cast<DocumentReference>();
    List<Note> createdNotes = [];
    List<Note> savedNotes = [];
    for (DocumentReference noteref in createdNotesRefs) {
      DocumentSnapshot response = await noteref.get();
      var note = response.data;
      createdNotes.add(new Note.map(note));
    }
    for (DocumentReference noteref in savedNotesRefs) {
      DocumentSnapshot response = await noteref.get();
      var note = response.data;
      savedNotes.add(new Note.map(note));
    }
    data['created_notes'] =createdNotes;
    data['saved_notes'] =savedNotes;
    return data;
  }

  static _convertNotesToRefs(User user) {
    List<Note> createdNotes = user.createdNotes;
    List<Note> savedNotes = user.savedNotes;

    List<DocumentReference> createNotesRefs = [];
    List<DocumentReference> savedNotesRefs = [];

    for (Note note in createdNotes) {
      DocumentReference ref = _getNoteRef(note.id);
      createNotesRefs.add(ref);
    }

    for (Note note in savedNotes) {
      DocumentReference ref =_getNoteRef(note.id);
      savedNotesRefs.add(ref);
    }

    var userObj = user.toObject();
    userObj['saved_notes'] = savedNotesRefs;
    userObj['created_notes'] = createNotesRefs;
    return new User.map(userObj);
  }

  static DocumentReference _getNoteRef(id) {
    return notesReference.document(id);
  }
}