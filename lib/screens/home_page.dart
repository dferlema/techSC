import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2), // Azul principal
        title: Row(
          children: [
            Icon(Icons.computer, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Tech Service Computer',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              // Acción para el menú hamburguesa
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Menú seleccionado')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección 1: Sobre Nosotros
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF1976D2), // Mismo azul que el AppBar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sobre Nosotros',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Somos una empresa líder en servicios técnicos de computadoras, comprometidos con ofrecer soluciones tecnológicas de calidad y un servicio excepcional a nuestros clientes.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Sección 2: Estadísticas
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(Icons.people, '5000+', 'Clientes Satisfechos'),
                  _buildStatCard(
                    Icons.workspace_premium,
                    '15+',
                    'Años de Experiencia',
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Sección 3: Nuestro Equipo
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuestro Equipo',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Profesionales dedicados y apasionados por la tecnología',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  _buildTeamMember(
                    name: 'Diego Lema',
                    role: 'Director Técnico',
                    description:
                        'Experto en reparación de hardware con 20 años de experiencia',
                    icon: Icons.people,
                  ),
                  SizedBox(height: 24),
                  _buildTeamMember(
                    name: 'María González',
                    role: 'Especialista en Software',
                    description:
                        'Certificada en sistemas operativos y desarrollo de software',
                    icon: Icons.people,
                  ),
                  SizedBox(height: 24),
                  _buildTeamMember(
                    name: 'Juan Martínez',
                    role: 'Gerente de Ventas',
                    description:
                        'Especialista en soluciones tecnológicas para empresas',
                    icon: Icons.people,
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Sección 4: Soporte Disponible
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xFF1976D2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '24/7',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Soporte Disponible',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Sección 5: Nuestra Historia
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuestra Historia',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Fundada en 2012, TechService Computer nació de la pasión por la tecnología y el deseo de brindar servicios técnicos de calidad a nuestra comunidad. Lo que comenzó como un pequeño taller se ha convertido en una empresa de referencia en el sector.\n\nCon más de 15 años de experiencia, hemos atendido a miles de clientes satisfechos, desde usuarios domésticos hasta grandes empresas. Nuestro compromiso con la excelencia y la innovación nos ha permitido crecer y adaptarnos a las constantes evoluciones tecnológicas.\n\nHoy en día, ofrecemos una amplia gama de servicios que incluyen reparación de hardware, instalación de software, venta de equipos y accesorios, y soporte técnico especializado.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Sección 6: Nuestra Misión
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuestra Misión',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Proporcionar soluciones tecnológicas innovadoras y servicios técnicos de la más alta calidad, superando las expectativas de nuestros clientes y contribuyendo al avance tecnológico de nuestra comunidad.',
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Sección 7: Nuestros Valores
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuestros Valores',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildValueItem('Excelencia en el servicio'),
                      SizedBox(height: 8),
                      _buildValueItem('Honestidad y transparencia'),
                    ],
                  ),
                ),
              ),
            ),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revisa nuestros productos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Encuentra lo que necesitas para tus proyectos tecnológicos',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/products');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: const Text(
                        'Ver Productos',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // En home_page.dart, después de la sección "Nuestros Valores"
            SizedBox(height: 24),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Necesitas Soporte?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Reserva una cita técnica y te atenderemos lo antes posible.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/reserve-service');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size(double.infinity, 40),
                      ),
                      child: Text('Reservar Servicio Técnico'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40), // Espacio final
          ],
        ),
      ),
    );
  }

  // Método auxiliar para construir las tarjetas de estadísticas
  Widget _buildStatCard(IconData icon, String number, String label) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Color(0xFFE3F2FD), // Azul claro
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(0xFF1976D2), size: 40),
        ),
        SizedBox(height: 12),
        Text(
          number,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  // Método auxiliar para construir un miembro del equipo
  Widget _buildTeamMember({
    required String name,
    required String role,
    required String description,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Color(0xFFE3F2FD),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(0xFF1976D2), size: 40),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                role,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Método auxiliar para construir un ítem de valor
  Widget _buildValueItem(String value) {
    return Row(
      children: [
        Icon(Icons.check, color: Colors.green, size: 20),
        SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 16)),
      ],
    );
  }
}
