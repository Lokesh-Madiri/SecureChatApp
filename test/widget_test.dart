import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();

    await fakeFirestore.collection('users').doc('user1').set({
      'name': 'Test User',
      'email': 'test@example.com',
    });
  });

  test('Fetch user data', () async {
    final doc = await fakeFirestore.collection('users').doc('user1').get();
    final data = doc.data(); // Must call .data() to get the map

    expect(data?['name'], 'Test User');
    expect(data?['email'], 'test@example.com');
  });
}
