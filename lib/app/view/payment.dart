import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/payment_controller.dart';
import 'package:get/get.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaymentController>(
      builder: (value) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Payment'),
            centerTitle: true,
          ),
          body: value.isLoading.value
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course details
                        if (value.course.value != null)
                          Card(
                            child: ListTile(
                              title: Text(value.course.value!.title),
                              subtitle: Text(value.formatPrice(value.total.value)),
                            ),
                          ),
                        SizedBox(height: 20),
                        
                        // Payment form would go here
                        Text(
                          'Payment Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 10),
                        
                        // Billing information form
                        TextField(
                          controller: value.firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: value.lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: value.emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 20),
                        
                        // Payment method selection
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 10),
                        
                        // Payment methods list
                        ...value.paymentMethods.map((method) => 
                          RadioListTile<String>(
                            title: Text(method['name']),
                            value: method['id'],
                            groupValue: value.selectedPaymentMethod.value,
                            onChanged: method['enabled'] 
                              ? (val) => value.selectPaymentMethod(val!)
                              : null,
                          )
                        ).toList(),
                        
                        SizedBox(height: 20),
                        
                        // Process payment button
                        Center(
                          child: ElevatedButton(
                            onPressed: value.isProcessingPayment.value
                              ? null
                              : () => value.processPayment(),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                value.isProcessingPayment.value
                                  ? 'Processing...'
                                  : 'Complete Payment',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}