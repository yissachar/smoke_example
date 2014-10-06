library smoke_example;

import 'package:smoke/smoke.dart';

void main() {
  var person = new Person();
  person.firstName = 'John';
  person.lastName = 'Smith';
  print(person);
}

class Person extends Object with BoilerplateToString {
  String firstName;
  String lastName;

  //@override
  String toString() => '$firstName $lastName';
}

abstract class BoilerplateToString {

  @override
  String toString () {
    var str = '';

    List<Declaration> declarations = query(this.runtimeType,
        new QueryOptions(includeProperties: false));

    for(var declaration in declarations) {
      str += '${read(this, declaration.name)} ';
    }

    return str;
  }
}