import 'package:flutter/material.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';

class RegisterPage extends StatelessWidget {
  final TextEditingController _emailController =TextEditingController();
  final TextEditingController _pswController = TextEditingController();
  final TextEditingController _confirmpswController = TextEditingController();
  final void Function()? onTap;

  RegisterPage({super.key,required this.onTap});

  void register(){}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // force white background
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Image.asset(
          'assets/images/logo216.png',
          width: 50,
          height: 50,
        ),
        elevation: 8.0,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // center it vertically
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
        
            ),
            const SizedBox(height: 50),
            Text(
              "Let's create an account for you",
              style: TextStyle(
                color: Colors.black, // make sure text visible
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 50),
            MyTextfield(holderPlace: "Email",obscurtext: false,controller: _emailController,),
            const SizedBox(height: 20),
            MyTextfield(holderPlace: "Password" , obscurtext: true,controller: _pswController,),
            const SizedBox(height: 20),
            MyTextfield(holderPlace: "Confirm Password" , obscurtext: true,controller: _confirmpswController,),
            const SizedBox(height: 25),
            MyButton(text: "Register",onTap: register,),
            const SizedBox(height: 25),
        
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Already have an account ?",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary
                  ),),
                GestureDetector(
                  onTap: onTap,
                  child: Text("Login now",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
        
                    ),
                  )
                )
        
              ],
            )
          ],
        ),
      ),
    );

  }
}
